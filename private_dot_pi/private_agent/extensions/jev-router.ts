// Copied from: https://github.com/earendil-works/pi/blob/540e174c72cd793170b73db8160c6d5f6c5a2236/packages/coding-agent/examples/extensions/jev-router.ts

/**
 * Jev router - a virtual model that plans on a strong model and implements on a cheap one.
 *
 * Registers `jev/auto`, which routes between three OpenAI Codex models:
 *
 * - Planning: GPT-6.1 Sol (high) for complex work, GPT-6.1 Sol (medium) otherwise. The Jev classifier rates the
 *   first user message; planning stays on the chosen model.
 * - Implementation: GPT-6.1 Terra (medium).
 *
 * The planning model explores, plans, and makes the first edit. After the first successful `edit`
 * or `write` tool call (including nested calls from codemode), the next request of the same turn goes to Terra, and the session stays
 * there. A session therefore switches models once and accepts a single prompt-cache miss.
 *
 * The phase is router state: Pi stores it on the session branch, so it follows the session tree
 * and survives compaction. Requests outside the agent loop, such as compaction summaries, go to Terra.
 *
 * Requires TypeSafe credentials (TYPESAFE_API_KEY) and an OpenAI Codex login.
 * Usage: pi -e ./jev-router.ts --model jev/auto
 */

import type { Message, ModelThinkingLevel } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext, ModelRoute, ModelRouteRequest } from "@earendil-works/pi-coding-agent";

interface RouteTarget {
	provider: string;
	model: string;
	thinkingLevel: ModelThinkingLevel;
}

const ROUTES = {
	complex: { provider: "openai-codex", model: "gpt-6.1-sol", thinkingLevel: "high" },
	standard: { provider: "openai-codex", model: "gpt-6.1-sol", thinkingLevel: "medium" },
	implementation: { provider: "openai-codex", model: "gpt-6.1-terra", thinkingLevel: "medium" },
} satisfies Record<string, RouteTarget>;

/** Tools whose successful result means implementation has started. */
const EDIT_TOOLS = new Set(["edit", "write"]);

interface JevState {
	phase: "planning" | "implementation";
	/** OpenAI Codex model for this phase. */
	route: RouteTarget;
}

type JevRequest = ModelRouteRequest<JevState>;

function routeTo(ctx: ExtensionContext, route: RouteTarget, state?: JevState): ModelRoute<JevState> {
	const model = ctx.modelRegistry.find(route.provider, route.model);
	if (!model) throw new Error(`Model ${route.provider}/${route.model} is not in the catalog`);
	return { model, thinkingLevel: route.thinkingLevel, state };
}

function lastUserText(messages: readonly Message[]): string {
	const content = messages.filter((message) => message.role === "user").at(-1)?.content ?? "";
	if (typeof content === "string") return content;
	return content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("\n");
}

/** Whether a tool call since the last user message edited a file successfully. */
function editedThisTurn(messages: readonly Message[]): boolean {
	const lastUser = messages.findLastIndex((message) => message.role === "user");
	return messages.slice(lastUser + 1).some((message) => {
		if (message.role !== "toolResult") return false;
		if (EDIT_TOOLS.has(message.toolName) && !message.isError) return true;
		// A nested edit can succeed even if its enclosing script later fails.
		return message.nestedCalls?.calls.some((call) => EDIT_TOOLS.has(call.name) && call.status === "ok") ?? false;
	});
}

/** Planning model for a new session: Sol (high) for complex work, Sol (medium) otherwise or when Jev is unavailable. */
async function choosePlanningRoute(request: JevRequest, ctx: ExtensionContext): Promise<RouteTarget> {
	// Keep a planning model the session already uses, so switching to jev/auto costs no cache miss.
	const previous = request.previous;
	for (const route of [ROUTES.complex, ROUTES.standard]) {
		if (
			previous?.model.provider === route.provider &&
			previous.model.id === route.model &&
			previous.thinkingLevel === route.thinkingLevel
		) {
			return route;
		}
	}

	const jev = ctx.modelRegistry.findOfType("classifier", "typesafe", "jev-latest");
	if (!jev) return ROUTES.standard;
	const result = await ctx.modelRegistry.classify(
		jev,
		{
			state: { prompt: lastUserText(request.messages).slice(0, 16_000) },
			questions: {
				complexity: {
					type: "choice",
					instructions: "How demanding is the software engineering work requested in `prompt`?",
					criteria: {
						standard: "Ordinary features, fixes, reviews, or questions",
						complex: "Subtle design, cross-cutting changes, or hard debugging",
					},
				},
			},
		},
		{ signal: request.signal },
	);
	const answer = result.stopReason === "stop" ? result.answers.complexity : undefined;
	return answer?.type === "choice" && (answer.probabilities.complex ?? 0) >= 0.5
		? ROUTES.complex
		: ROUTES.standard;
}

export default function (pi: ExtensionAPI) {
	pi.registerVirtualModel<JevState>({
		provider: "jev",
		id: "auto",
		name: "Auto (Jev)",
		// Shared by all three models; shown before the first response.
		contextWindow: 272_000,
		maxTokens: 128_000,
		async route(request, ctx) {
			if (request.reason === "direct") return routeTo(ctx, ROUTES.implementation);
			const state = request.state;
			if (!state) {
				const route = await choosePlanningRoute(request, ctx);
				return routeTo(ctx, route, { phase: "planning", route });
			}
			// The planning model made the first edit: hand the rest of the work to Terra.
			if (state.phase === "planning" && editedThisTurn(request.messages)) {
				return routeTo(ctx, ROUTES.implementation, {
					phase: "implementation",
					route: ROUTES.implementation,
				});
			}
			return routeTo(ctx, state.route);
		},
	});
}
