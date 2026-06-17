# swift-json

[English](README.md) · **한국어**

Swift용 값 타입 JSON 모델과, 타입으로부터 [JSON Schema](https://json-schema.org)를 생성하는 매크로.

> 디렉터리·repo 이름은 `swift-json`이지만, import하는 모듈은 **`JSON`** 하나이다.
>
> ```swift
> import JSON
> ```

## 왜 (Why)

Swift에서 JSON을 다루는 길은 두 가지인데, 그 사이에 공백이 있다.

- **`Codable`**은 모양을 미리 알 때 훌륭하다. 그러나 모양이 동적이거나 일부만 알거나, 임의의 JSON을 *들고 다니며 조작*해야 할 때(두 페이로드 병합, 웹훅에서 한 필드 추출, 런타임에 요청 본문 조립) 불편해진다.
- **`JSONSerialization`**은 `Any` / `[String: Any]`를 준다. 접근할 때마다 강제 캐스팅해야 하고, `Sendable`이 아니며, 패턴 매칭이 안 되고, 정수/실수 구분이 무너지며(`42`와 `42.0`이 구별 불가), 객체 키 순서를 보존하지 않는다.

그리고 둘 다 세 번째 필요를 해결하지 못한다 — **Swift 타입으로부터 JSON Schema 생성.** LLM 도구/함수 호출, 요청 검증, API 문서는 모두 모델과 일치하는 스키마를 원하는데, 손으로 작성한 스키마는 타입과 조용히 어긋난다.

## 무엇을 (What)

1. **`JSON` — 임의 JSON을 위한 값 타입.** 닫힌 `enum`(`null` / `bool` / `number` / `string` / `array` / `object`)으로 `Sendable`·`Hashable`·`Codable`이며, 패턴 매칭·리터럴 생성·안전한 접근자/서브스크립트·순서 보존 파서/직렬화기를 갖춘다. `Any`도, 강제 캐스팅도, 타입 정보 손실도 없다.
2. **`@JSONSchemaModel` — 어긋나지 않는 스키마.** 타입에 붙이면 실제 저장 프로퍼티로부터 JSON Schema(draft 2020-12)가 컴파일 타임에 생성된다.

## 설치

Swift Package Manager — 패키지를 추가한다.

```swift
dependencies: [
    .package(url: "https://github.com/geonu1109/swift-json.git", from: "1.0.0"),
],
```

그리고 `JSON` 프로덕트에 의존한다.

```swift
.target(name: "YourTarget", dependencies: [
    .product(name: "JSON", package: "swift-json"),
]),
```

`import JSON` 하나로 값 모델, JSONSchema 타입, `@JSONSchemaModel` 매크로가 모두 따라온다. 매크로는 [swift-syntax](https://github.com/swiftlang/swift-syntax) 위에 구현되지만, Swift 6.2+ 툴체인에서는 SwiftPM이 이를 **사전 빌드(prebuilt)** 바이너리로 내려받으므로 소스에서 다시 컴파일하지 않는다.

Xcode에서는 **File ▸ Add Package Dependencies…**를 열고 저장소 URL을 입력한다.

## 사용법

### `JSON` 값

```swift
import JSON

var value: JSON = [
    "name": "Ada",
    "age": 36,
    "tags": ["math", "engines"],
    "manager": nil,
]

value["name"]?.stringValue        // "Ada"
value["age"]?.intValue            // 36
value["tags"]?[1]?.stringValue    // "engines"
value["new"] = "added"            // 제자리에서 수정

let text = value.encoded(prettyPrinted: true)   // 순서 보존 + pretty JSON
let parsed = try JSON.parse(text)               // 순서 보존 파서
```

임의의 `Codable` 타입과 상호 변환한다.

```swift
struct Point: Codable { var x, y: Int }
let json = try JSON(encodable: Point(x: 1, y: 2))
let point = try json.decode(Point.self)
```

### `@JSONSchemaModel` 매크로

`struct`·`class`·raw-value `enum`에 `@JSONSchemaModel`을 붙이면 `JSONSchemaRepresentable` 준수가 생성되고 타입에 `static var jsonSchema: JSONSchema`가 추가된다.

```swift
import JSON

@JSONSchemaModel
struct Person {
    var name: String
    @JSONSchemaProperty(description: "Years since birth")
    var age: Int
    var nickname: String?     // 옵셔널 → required에서 제외
    var scores: [Double]
}

print(Person.jsonSchema.encoded())
```

```json
{
  "type": "object",
  "properties": {
    "name": { "type": "string" },
    "age": { "type": "integer", "description": "Years since birth" },
    "nickname": { "type": "string" },
    "scores": { "type": "array", "items": { "type": "number" } }
  },
  "required": ["name", "age", "scores"],
  "additionalProperties": false
}
```

- 옵셔널이 아닌 저장 프로퍼티는 `required`가 된다.
- `[T]`, `[String: V]`, `Set<T>`, 중첩된 `@JSONSchemaModel` 타입이 자동으로 조합된다.
- raw-value enum(`String`/정수)은 `enum` 스키마가 되며, 정수의 암묵적 값도 추론한다.
- `@JSONSchemaModel(additionalProperties: true)`로 객체를 느슨하게 연다.
- `CodingKeys` enum을 따른다. 프로퍼티는 coding key 이름으로 변환되고, `CodingKeys`에서 누락된 프로퍼티는 제외된다(`Codable`과 동일).
- 어노테이션 없는 프로퍼티는 리터럴 초깃값에서 추론한다(`var count = 0` → integer). 추론 불가능하면 조용히 버리지 않고 해당 프로퍼티를 가리키는 빌드 경고를 출력한다.

자기참조·상호재귀 타입은 `$ref`/`$defs`로 처리되어 생성이 항상 종료된다.

```swift
@JSONSchemaModel
struct TreeNode {
    var value: String
    var children: [TreeNode]
}
// → { "$ref": "#/$defs/TreeNode", "$defs": { "TreeNode": { … "items": { "$ref": "#/$defs/TreeNode" } } } }
```

(`struct`는 `Array`처럼 힙 기반 타입을 통해서만 재귀할 수 있다. 링크드 리스트 같은 옵셔널 자기참조에는 `class`를 사용한다.) 매크로가 다루지 못하는 경우 `JSONSchema`를 직접 사용한다.

```swift
let schema = JSONSchema.object(
    properties: [("id", .string), ("count", .integer)],
    required: ["id"]
).with(description: "A record")
```

## 동작 원리

- **`JSON`**은 닫힌 `indirect enum`이다. 객체는 삽입 순서를 보존하는 유일 키 저장소 `JSONObject`를 쓰고, 숫자는 정수/실수 태그를 들고 다녀 둘이 섞이지 않는다.
- **파싱과 직렬화**는 `JSONSerialization` 대신 손으로 쓴 재귀 하강 방식이다 — Foundation이 객체 키 순서를 보존하지 않기 때문이다.
- **매크로**는 [swift-syntax](https://github.com/swiftlang/swift-syntax) 컴파일러 플러그인(`JSONMacros`)으로, `JSON` 모듈 안에 함께 담겨 import 하나로 전부 다룬다. Swift 6.2+에서는 SwiftPM이 소스 빌드 대신 사전 빌드된 swift-syntax를 사용한다. 각 모델은 진행 중인 타입을 추적하는 `JSONSchemaContext`를 통해 스키마를 기여한다 — 순환은 `$defs`의 `$ref`로 끊고, 비순환 타입은 inline로 둔다.

## 보장 동작

신뢰할 수 있는 동작이자 테스트가 검증하는 기준이다.

- **배열 원소 순서**는 항상 보존된다.
- **객체 키 순서**는 `JSON.parse(_:)`와 `encoded()` 경로에서 보존된다.
  - ⚠️ `JSON` 값이 다른 `Codable` 타입에 중첩되어 외부 디코더(예: Foundation `JSONDecoder`)로 디코드될 때는 키 순서가 보존되지 **않는다** — Foundation이 키를 순서 없이 내놓는다. 순서가 중요하면 `JSON.parse(_:)`를 쓴다.
- **객체 키는 유일하다.** 중복 이름이 있는 입력을 파싱하면 첫 위치를 유지하고 마지막 값을 취한다: `{"a":1,"a":2}` → `{"a":2}`. RFC 8259("이름은 유일해야 한다")와 일반 파서 동작을 따른다.
- **객체 동등성은 키 순서를 무시한다.** `["a": 1, "b": 2] == ["b": 2, "a": 1]` — 객체는 스펙상 순서가 없으므로 순서는 *표현(presentational)* 속성이다. 직렬화에는 영향을 주지만 `==`/`hashValue`에는 영향을 주지 않는다. (배열은 순서 민감을 유지한다.)
- **`42`와 `42.0`은 구별된다**(`JSONNumber.integer` vs `.floatingPoint`). 파싱·직렬화를 거쳐도 유지된다.
- **파서는 엄격하고 경계가 있다.** 잘못된 숫자(`01`, `1.`, `+1`, `1e`), 이스케이프 안 된 제어문자, 비유한(non-finite)으로 넘치는 값을 거부하고, 중첩 깊이를 128로 제한해 악의적 입력이 스택을 넘치지 못하게 한다. 접근자는 trap하지 않는다 — `intValue`는 비유한·범위 밖 값에 `nil`을 반환하고, 비유한 숫자는 invalid JSON 대신 `null`로 직렬화된다.

### 한계

- **숫자 정밀도.** 숫자는 `Int` 또는 `Double`로 저장된다. `Int` 범위를 넘는 정수(또는 `Double` 정밀도를 넘는 소수)는 `Double`로 떨어져 정밀도를 잃는다 — JavaScript `JSON.parse`와 같은 트레이드오프.
- **매크로 `$defs` 이름**은 타입의 단순 이름을 쓴다. 서로 다른 두 타입이 같은 이름이면 두 번째에 숫자 접미사가 붙는다(`Foo`, `Foo_2`).
- **매크로 타입 추론**은 스칼라 리터럴(`Int`, `Double`, `String`, `Bool`)까지 지원한다. 그 외 어노테이션 없는 프로퍼티엔 명시적 어노테이션을 추가한다(누락분은 빌드 경고).
- **다른 타입 안에 중첩된 모델**이 형제/자기 자신을 단순 이름으로 참조하면 컴파일에 실패할 수 있다 — 생성된 extension이 파일 스코프에 있어서 거기선 `A.B`가 `B`가 아니기 때문. `@JSONSchemaModel` 타입은 파일 스코프에 선언한다.

## 요구 사항

Swift 6.2+ · macOS 13 / iOS 16 / tvOS 16 / watchOS 9 / visionOS 1. 매크로를 위해 [swift-syntax](https://github.com/swiftlang/swift-syntax)에 의존하지만, 6.2+ 툴체인에서는 SwiftPM이 이를 사전 빌드 바이너리로 내려받으므로 소스에서 재컴파일하지 않는다.
