import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AddCityEmptyStateIllustration" asset catalog image resource.
    static let addCityEmptyStateIllustration = DeveloperToolsSupport.ImageResource(name: "AddCityEmptyStateIllustration", bundle: resourceBundle)

    /// The "HoursLogo" asset catalog image resource.
    static let hoursLogo = DeveloperToolsSupport.ImageResource(name: "HoursLogo", bundle: resourceBundle)

    /// The "settings_parallax_back_dark" asset catalog image resource.
    static let settingsParallaxBackDark = DeveloperToolsSupport.ImageResource(name: "settings_parallax_back_dark", bundle: resourceBundle)

    /// The "settings_parallax_back_light" asset catalog image resource.
    static let settingsParallaxBackLight = DeveloperToolsSupport.ImageResource(name: "settings_parallax_back_light", bundle: resourceBundle)

    /// The "settings_parallax_front_dark" asset catalog image resource.
    static let settingsParallaxFrontDark = DeveloperToolsSupport.ImageResource(name: "settings_parallax_front_dark", bundle: resourceBundle)

    /// The "settings_parallax_front_light" asset catalog image resource.
    static let settingsParallaxFrontLight = DeveloperToolsSupport.ImageResource(name: "settings_parallax_front_light", bundle: resourceBundle)

    /// The "settings_parallax_mid_dark" asset catalog image resource.
    static let settingsParallaxMidDark = DeveloperToolsSupport.ImageResource(name: "settings_parallax_mid_dark", bundle: resourceBundle)

    /// The "settings_parallax_mid_light" asset catalog image resource.
    static let settingsParallaxMidLight = DeveloperToolsSupport.ImageResource(name: "settings_parallax_mid_light", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "AddCityEmptyStateIllustration" asset catalog image.
    static var addCityEmptyStateIllustration: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .addCityEmptyStateIllustration)
#else
        .init()
#endif
    }

    /// The "HoursLogo" asset catalog image.
    static var hoursLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .hoursLogo)
#else
        .init()
#endif
    }

    /// The "settings_parallax_back_dark" asset catalog image.
    static var settingsParallaxBackDark: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxBackDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_back_light" asset catalog image.
    static var settingsParallaxBackLight: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxBackLight)
#else
        .init()
#endif
    }

    /// The "settings_parallax_front_dark" asset catalog image.
    static var settingsParallaxFrontDark: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxFrontDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_front_light" asset catalog image.
    static var settingsParallaxFrontLight: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxFrontLight)
#else
        .init()
#endif
    }

    /// The "settings_parallax_mid_dark" asset catalog image.
    static var settingsParallaxMidDark: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxMidDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_mid_light" asset catalog image.
    static var settingsParallaxMidLight: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .settingsParallaxMidLight)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "AddCityEmptyStateIllustration" asset catalog image.
    static var addCityEmptyStateIllustration: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .addCityEmptyStateIllustration)
#else
        .init()
#endif
    }

    /// The "HoursLogo" asset catalog image.
    static var hoursLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .hoursLogo)
#else
        .init()
#endif
    }

    /// The "settings_parallax_back_dark" asset catalog image.
    static var settingsParallaxBackDark: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxBackDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_back_light" asset catalog image.
    static var settingsParallaxBackLight: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxBackLight)
#else
        .init()
#endif
    }

    /// The "settings_parallax_front_dark" asset catalog image.
    static var settingsParallaxFrontDark: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxFrontDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_front_light" asset catalog image.
    static var settingsParallaxFrontLight: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxFrontLight)
#else
        .init()
#endif
    }

    /// The "settings_parallax_mid_dark" asset catalog image.
    static var settingsParallaxMidDark: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxMidDark)
#else
        .init()
#endif
    }

    /// The "settings_parallax_mid_light" asset catalog image.
    static var settingsParallaxMidLight: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .settingsParallaxMidLight)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

