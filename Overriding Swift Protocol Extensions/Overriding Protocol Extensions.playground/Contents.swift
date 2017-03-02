/*: 
 
 # Overriding Protocol Extension Default Implementations

 Swift encourages protocol oriented development. Default implementations provide a powerful tool for composing types. Using these tools in combination with class inheritance has some surprising consequences which can result in unexpected behavior.  Let's explore an example and see what we can do to avoid such problems.

 Alexandros Salazar's ["The Ghost of Swift Bugs Future"](https://nomothetis.svbtle.com/the-ghost-of-swift-bugs-future) and Kevin Ballard's ["Method Dispatch in Protocol Extensions"](https://oleb.net/blog/2016/06/kevin-ballard-swift-dispatch/) posts cover the dispatch rules in use here in more detail.
 */
/*:
 ### The goal

 I wanted serveral types to implement the same behavior so it's time for a protocol. Let's say I wanted all these types to be configurable based on some sort of stored configuration data which is loaded from a file.
 */
import UIKit

protocol Configurable {
    func configurationFileName() -> String
}

/*:
 Most of the time I want to use some common default configuration.  So I extend the protocol with a default implementation to specify that default configuration file.
 */
extension Configurable {
    func configurationFileName() -> String {
        return "default.config"
    }
}

/*:
 When I create `Configurable` structs this works great. My types get the default implementation but can also provide their own version.
 */
enum SimpleStructUse {
    // Adopting the protocol gives us the default behavior
    struct ConfigurableStruct: Configurable {}

    // We can customize this behavior by supplying our own implementation
    struct CustomConfigurableStruct: Configurable {
        func configurationFileName() -> String {
            return "custom.config"
        }
    }

    // We can also use the same behavior on classes
    class BaseView: UIView, Configurable {}

    class CustomView: BaseView {
        func configurationFileName() -> String {
            return "custom.config"
        }
    }
}

SimpleStructUse.ConfigurableStruct().configurationFileName()
SimpleStructUse.CustomConfigurableStruct().configurationFileName()

/*:
 I can also create `Configurable` classes. At first this works fine.
 */
enum SimpleClassUse {
    class BaseView: UIView, Configurable {}

    class CustomView: BaseView {
        func configurationFileName() -> String {
            return "custom.config"
        }
    }
}

SimpleClassUse.BaseView().configurationFileName()
SimpleClassUse.CustomView().configurationFileName()

/*:
 ### The bug

 Problems appear when I subclass a `Configurable` class.
 */
enum Failure {
    // Default implementation of `configurationFileName` is fine for this type
    class BaseView: UIView, Configurable {
        func configure() -> String {
            return "using \(self.configurationFileName())"
        }
    }

    // and here we're happy to reuse our inherited `configure` method
    class CustomView: BaseView {
        func configurationFileName() -> String {
            return "custom.config"
        }
    }
}

Failure.BaseView().configure()
Failure.CustomView().configure()

/*:
 Here my parent `baseView` class is using `self` to invoke the default implementation of a `Configurable` method. My child `CustomView` class is providing it's own implementation of that `Configurable` method. Due to Swift's method dispatch rules this child class' implementation is never called and the default implemention is always used.
 */
/*:
 ### Solutions

 One workaround is to drop the default implementation. If we have a small number of classes adopting `Configurable` this might be fine. If we have lots of `Configurables` then this becomes less satisfying.
 */
protocol ConfigurableWithoutDefaultImplementation {
    func configurationFileName() -> String
}

enum ReimplementedOnEachBaseClass {
    class BaseView: UIView, ConfigurableWithoutDefaultImplementation {
        func configurationFileName() -> String {
            return "default.config"
        }

        func configure() -> String {
            return "using \(self.configurationFileName())"
        }
    }

    class CustomView: BaseView {
        override func configurationFileName() -> String {
            return "custom.config"
        }
    }

    class OtherCustomView: BaseView {
    }
}

ReimplementedOnEachBaseClass.BaseView().configure()
ReimplementedOnEachBaseClass.CustomView().configure()
ReimplementedOnEachBaseClass.OtherCustomView().configure()

/*:
 The [swift evolution mailing list](https://lists.swift.org/pipermail/swift-evolution/Week-of-Mon-20151207/001125.html) suggests two additional workarounds. If classes always implement protocol methods and call any default implementations then they will always use dynamic dispatching and be able to invoke overrides from subclasses.

 Calling default implementations can be a little tricky as well.

 One option is to avoid default implementations of methods declared in the protocol. Methods added to the protocol in an extension will always be statically dispatched so we can then call the default implementation from our class' dynamically dispatched version of the method. Unfortunately this means that the set of methods we need to implement and call default implementations of are all methods not listed in the protocol itself so it's difficult to identify them when implementing a protocol conforming class.
 */
protocol ConfigurableWithoutMethodDeclaration {

}

extension ConfigurableWithoutMethodDeclaration {
    func configurationFileName() -> String {
        return "default.config"
    }
}

enum DefaultImplementationWithoutProtocolDeclaration {
    class BaseView: UIView, ConfigurableWithoutMethodDeclaration {
        func configurationFileName() -> String {
            return (self as ConfigurableWithoutMethodDeclaration).configurationFileName()
        }

        func configure() -> String {
            return "using \(self.configurationFileName())"
        }
    }

    class CustomView: BaseView {
        override func configurationFileName() -> String {
            return "custom.config"
        }
    }
}

DefaultImplementationWithoutProtocolDeclaration.BaseView().configure()
DefaultImplementationWithoutProtocolDeclaration.CustomView().configure()

/*:
 A second option is to define a wrapper type which can use a statically dispatched call to the default implementation. This allows us to include function declarations in our protocol definition but a large protocol with many required methods may be hard to write a wrapper type for.
 */
enum DefaultImplementationWrappers {
    class BaseView: UIView, Configurable {
        func configurationFileName() -> String {
            struct ConfigurableWrapper: Configurable {}
            let wrapper = ConfigurableWrapper()
            return wrapper.configurationFileName()
        }

        func configure() -> String {
            return "using \(self.configurationFileName())"
        }
    }

    class CustomView: BaseView {
        override func configurationFileName() -> String {
            return "custom.config"
        }
    }
}

DefaultImplementationWrappers.BaseView().configure()
DefaultImplementationWrappers.CustomView().configure()

/*:
 ### Summary

 We've seen that subclasses cannot reliably override protocol methods they inherit from their parent class when those methods have default implementations in a protocol extension. This causes confusing behavior where a subclass can implement protocol methods only to discover that they are never called from behavior inherited from a superclass. This can be a source of confusing bugs and identifying the root cause requires inspecting the behavior of all our parent classes. Something that can be especially difficult if we were to subclass a framework provided class.
 
 To avoid creating types which are likely to introduce bugs in the future we can choose to either:

 1. Use only value types with behaviors composed from protocol default implementations.
 2. Use classes and restrict ourselves to adopting protocols without default implementations.
 3. Use final classes when adopting protocols with default implementations so we cannot have problematic subclasses.
 4. When defining a non-final class which implements protocols with default implementations reimplement those protocol methods and call the default implementation.
 */
