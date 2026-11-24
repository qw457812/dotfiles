import { describe, expect, it } from "vitest";
import { passEntries } from "../extensions/himalaya.ts";

describe("himalaya pass entries", () => {
  it("reads string and array commands", () => {
    const config = `
[accounts.string]
imap.sasl.plain.password.command = "pass show string-form"

[accounts.array]
imap.sasl.plain.passwd.command = ["pass", "show", "array-form"]

[accounts.cmd]
smtp.sasl.login.password.cmd = ["/usr/bin/pass", "show", "nested/entry"]

[accounts.literal]
imap.sasl.xoauth2.token.command = 'pass show literal-form'

[accounts.inline]
jmap.auth.basic.password = { command = "sh -c 'pass show wrapped'" }

[accounts.header.imap.sasl.plain.password]
command = "pass show table-header"
`;
    expect(passEntries(config)).toEqual([
      "string-form",
      "array-form",
      "nested/entry",
      "literal-form",
      "wrapped",
      "table-header",
    ]);
  });

  it("ignores comments and other password managers", () => {
    const config = `
# imap.sasl.plain.password.command = "pass show commented"
smtp.sasl.plain.password.command = "pass show real" # pass show stale
imap.sasl.plain.password.command = "gopass show other"
smtp.sasl.plain.password.command = "passd show other"
jmap.auth.basic.password.command = "gpg --decrypt ~/.password-store/raw.gpg"
`;
    expect(passEntries(config)).toEqual(["real"]);
  });
});
