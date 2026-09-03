local eq = MiniTest.expect.equality
local new_set = MiniTest.new_set
local java = require("util.java")

local T = new_set()

local function parse(uri)
  return { java.parse_jdt_uri(uri) }
end

T["parse_jdt_uri()"] = new_set()

T["parse_jdt_uri()"]["parses source-named URIs"] = function()
  local uri = "jdt://contents/spring-data-redis-2.7.18.jar/org.springframework.data.redis.listener/"
    .. "KeyspaceEventMessageListener.java?=slfs-modules-charge/%5C/Users%5C/xingyuqiang%5C/.m2%5C/repository%5C/"
    .. "org%5C/springframework%5C/data%5C/spring-data-redis%5C/2.7.18%5C/spring-data-redis-2.7.18.jar"
    .. "=/maven.pomderived=/true=/%3Corg.springframework.data.redis.listener%28KeyspaceEventMessageListener.class"

  eq(parse(uri), {
    "spring-data-redis-2.7.18.jar",
    "org.springframework.data.redis.listener",
    "KeyspaceEventMessageListener",
  })
end

T["parse_jdt_uri()"]["gets inner class names from the handle"] = function()
  local uri = "jdt://contents/example.jar/com.example/Outer.java?=project/%5C/home%5C/user%5C/example.jar"
    .. "=/%3Ccom.example%28Outer%24Inner.class"

  eq(parse(uri), { "example.jar", "com.example", "Outer$Inner" })
end

T["parse_jdt_uri()"]["supports class-named paths and element handles"] = function()
  local uri = "jdt://contents/example.jar/com.example/Outer%24Inner.class?handle&element=Outer%24Inner.class"

  eq(parse(uri), { "example.jar", "com.example", "Outer$Inner" })
end

T["parse_jdt_uri()"]["supports the default package"] = function()
  local uri = "jdt://contents/example.jar/Main.java?=project/%5C/home%5C/user%5C/example.jar%28Main.class"

  eq(parse(uri), { "example.jar", "", "Main" })
end

T["parse_jdt_uri()"]["decodes URI components"] = function()
  local uri = "jdt://contents/example%20library.jar/com.example/Outer.java?handle&element=Outer%24Inner.class"

  eq(parse(uri), { "example library.jar", "com.example", "Outer$Inner" })
end

T["parse_jdt_uri()"]["rejects non-JDT and malformed URIs"] = new_set({
  parametrize = {
    { "file:///tmp/Example.class" },
    { "jdt://contents/example.jar/com.example/Example.class" },
    { "jdt://contents/example.jar/com.example/Example.class?invalid-handle" },
    { "jdt://contents/example.jar/com.example/Example.class?handle%28Example.java" },
  },
})

T["parse_jdt_uri()"]["rejects non-JDT and malformed URIs"]["returns nil"] = function(uri)
  eq(parse(uri), {})
end

T["jdt_uri_to_jar_path()"] = new_set()

T["jdt_uri_to_jar_path()"]["extracts Unix paths"] = function()
  local uri = "jdt://contents/example.jar/com.example/Example.java?=project/%5C/home%5C/user%5C/.m2%5C/repository%5C/"
    .. "com%5C/example%5C/example%5C/1.0%5C/example-1.0.jar=/%3Ccom.example%28Example.class"

  eq(java.jdt_uri_to_jar_path(uri), "/home/user/.m2/repository/com/example/example/1.0/example-1.0.jar")
end

T["jdt_uri_to_jar_path()"]["decodes macOS paths"] = function()
  local uri = "jdt://contents/example.jar/com.example/Example.java?=project/%5C/Users%5C/Jane%20Doe%5C/.m2%5C/"
    .. "repository%5C/example.jar=/%3Ccom.example%28Example.class"

  eq(java.jdt_uri_to_jar_path(uri), "/Users/Jane Doe/.m2/repository/example.jar")
end

T["jdt_uri_to_jar_path()"]["extracts Windows paths"] = function()
  local uri = "jdt://contents/example.jar/com.example/Example.java?=project/C:%5C/Users%5C/Jane%20Doe%5C/.m2%5C/"
    .. "repository%5C/example.jar=/%3Ccom.example%28Example.class"

  eq(java.jdt_uri_to_jar_path(uri), "C:/Users/Jane Doe/.m2/repository/example.jar")
end

T["jdt_uri_to_jar_path()"]["rejects URIs without a JAR handle"] = new_set({
  parametrize = {
    { "file:///home/user/example.jar" },
    { "jdt://contents/example.jar/com.example/Example.class" },
    { "jdt://contents/example.jar/com.example/Example.class?invalid-handle" },
  },
})

T["jdt_uri_to_jar_path()"]["rejects URIs without a JAR handle"]["returns nil"] = function(uri)
  eq(java.jdt_uri_to_jar_path(uri), nil)
end

return T
