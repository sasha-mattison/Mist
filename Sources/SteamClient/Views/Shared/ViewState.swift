import SwiftUI

/// Drop-in replacement for `@State`.
///
/// This SDK's `@State` is implemented via an attached macro (`SwiftUIMacros`)
/// whose compiler plugin only ships inside full Xcode.app — it isn't present
/// in a Command Line Tools-only toolchain, so `@State` fails to compile here
/// with "plugin for module 'SwiftUIMacros' not found". `SwiftUICore.State<Value>`
/// itself is still a plain (non-macro) property-wrapper struct, so this type
/// wraps it using the classic property-wrapper mechanism instead of the `@State`
/// attribute, sidestepping the missing plugin. Use `@ViewState` anywhere you'd
/// otherwise reach for `@State`.
@propertyWrapper
struct ViewState<Value>: DynamicProperty {
    private var box: SwiftUICore.State<Value>

    init(wrappedValue: Value) {
        box = SwiftUICore.State(wrappedValue: wrappedValue)
    }

    var wrappedValue: Value {
        get { box.wrappedValue }
        nonmutating set { box.wrappedValue = newValue }
    }

    var projectedValue: Binding<Value> {
        box.projectedValue
    }
}
