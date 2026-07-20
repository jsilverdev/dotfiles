---
name: mule-munit
description: Run and debug MuleSoft MUnit tests from Maven. Use when working in Mule projects with MUnit suites, when the user asks to run a specific MUnit suite or individual test, when MUnit filtering fails, or when PowerShell quoting affects Maven -Dmunit.test arguments.
---

# Mule MUnit

Use the MUnit Maven plugin selector instead of running every suite when the user asks for a specific Mule/MUnit test.

## Commands

Run one suite by matching the suite path/name relative to `src/test/munit`:

```powershell
mvn -q test "-Dmunit.test=.*pgdb-integration.*"
```

Run one test inside a matching suite:

```powershell
mvn -q test "-Dmunit.test=.*pgdb-integration.*#pgdb-get-by-bigint-id-integration-test"
```

Use regexes for both parts:

```powershell
mvn test "-Dmunit.test=<suite-regex>#<test-name-regex>"
```

## PowerShell

Always quote the whole `-Dmunit.test=...` argument in PowerShell. This prevents `#` from being parsed as a comment and avoids Maven receiving a broken lifecycle phase.

Good:

```powershell
mvn -q test "-Dmunit.test=.*db/pgdb-integration.*#.*bigint.*"
```

Bad:

```powershell
mvn -q -Dmunit.test=.*db/pgdb-integration.*#.*bigint.* test
```

## Fixtures

Prefer keeping test objects in `src/test/resources/mock/...` and loading them with `MunitTools::getResourceAsString('mock/...')` instead of embedding large inline objects in MUnit XML.

For payloads, use the resource string directly with the right media type:

```xml
<munit:payload value="#[MunitTools::getResourceAsString('mock/example/request.json')]" encoding="UTF-8" mediaType="application/json" />
```

For variables or attributes that must be objects, read the fixture explicitly:

```xml
<munit:variable key="inboundRequest" value="#[read(MunitTools::getResourceAsString('mock/example/inbound-request.json'), 'application/json')]" mediaType="application/java" />
```

Keep inline objects only when they are trivial scalars or when a fixture would make the test harder to read.

## Mocked Errors

When a `mock-when` must simulate a connector error, prefer a `then-return` error instead of routing through a helper flow. Provide either `typeId` or `cause`, not both.

```xml
<munit-tools:then-return>
  <munit-tools:error cause='#[java!java::lang::Exception::new("Exception Message")]' />
</munit-tools:then-return>
```

Use `cause` when the production error handler inspects `error.description` or `error.detailedDescription`. Use `typeId` instead when the handler only matches a Mule error type.

## Workflow

Before running MUnit tests:

1. Inspect `src/test/munit` to identify the suite file and test name.
2. If a database-backed integration suite is requested, prepare/reset required test data first.
3. Run the narrowest useful selector with `-Dmunit.test`.
4. If Maven says `No tests suites were found`, relax or correct the suite regex.
5. If Maven reports `Unknown lifecycle phase`, suspect shell quoting first.

## Source

This follows the official MuleSoft MUnit Maven Plugin documentation for `munit.test`, including suite regex and `suite#test` selection.
