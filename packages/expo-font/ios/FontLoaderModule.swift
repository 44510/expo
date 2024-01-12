import CoreGraphics
import ExpoModulesCore

public final class FontLoaderModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoFontLoader")

    Property("customNativeFonts") {
      return queryCustomNativeFonts()
    }

    AsyncFunction("loadAsync") { (fontFamilyAlias: String, localUri: URL) in
      if FontFamilyAliasManager.hasAlias(fontFamilyAlias) {
        throw FontAlreadyExistsException(fontFamilyAlias)
      }
      guard let data = FileManager.default.contents(atPath: localUri.path) else {
        throw FontFileNotFoundException((path: localUri.path, name: fontFamilyAlias))
      }
      guard let provider = CGDataProvider(data: data as CFData),
            let font = CGFont(provider) else {
        throw FontCreationFailedException(fontFamilyAlias)
      }
      var error: Unmanaged<CFError>?

      if !CTFontManagerRegisterGraphicsFont(font, &error), let error = error?.takeRetainedValue() {
        throw FontRegistrationFailedException(error)
      }
      if let fullName = font.fullName as? String, fontFamilyAlias != fullName {
        FontFamilyAliasManager.setAlias(fontFamilyAlias, forFamilyName: fullName)
      }
    }
  }
}

/**
 * Queries custom native font names from the Info.plist `UIAppFonts`.
 */
private func queryCustomNativeFonts() -> [String] {
  // [0] Read from main bundle's Info.plist
  guard let fontFilePaths = Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String] else {
    return []
  }

  // [1] Get font family names for each font file
  let fontFamilies: [[String]] = fontFilePaths.compactMap { fontFilePath in
    guard let fontUrl = Bundle.main.url(forResource: fontFilePath, withExtension: nil) as? URL else {
      return []
    }
    guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(fontUrl as CFURL) as? [CTFontDescriptor] else {
      return []
    }
    return fontDescriptors.compactMap { descriptor in
      return CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
    }
  }

  // [2] Retrieve font names by family names
  return fontFamilies.flatMap { fontFamilyNames in
    return fontFamilyNames.flatMap { fontFamilyName in
      return UIFont.fontNames(forFamilyName: fontFamilyName)
    }
  }
}
