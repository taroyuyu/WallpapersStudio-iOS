import XCTest
@testable import WallpapersApp
import Combine
import ComposableArchitecture

final class EditorReducerTests: XCTestCase {
  func testPresentImagePicker() {
    var didSendSignals = [AppTelemetry.Signal]()
    let store = TestStore(
      initialState: EditorState(),
      reducer: editorReducer,
      environment: MainEnvironment(
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    store.assert(
      .send(.menu(.importFromLibrary)),
      .receive(.presentImagePicker(true)) {
        $0.isPresentingImagePicker = true
      },
      .do {
        XCTAssertEqual(didSendSignals, [.importFromLibrary])
      },
      .send(.presentImagePicker(false)) {
        $0.isPresentingImagePicker = false
      }
    )
  }

  func testToggleMenu() {
    var didSendSignals = [AppTelemetry.Signal]()
    let store = TestStore(
      initialState: EditorState(),
      reducer: editorReducer,
      environment: MainEnvironment(
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    store.assert(
      .send(.toggleMenu) {
        $0.isPresentingMenu.toggle()
      },
      .do {
        XCTAssertEqual(didSendSignals, [.toggleMenu(false)])
      },
      .send(.toggleMenu) {
        $0.isPresentingMenu.toggle()
      },
      .do {
        XCTAssertEqual(didSendSignals.count, 2)
        XCTAssertEqual(didSendSignals.last, .toggleMenu(true))
      }
    )
  }

  func testLoadImage() {
    var didSendSignals = [AppTelemetry.Signal]()
    let store = TestStore(
      initialState: EditorState(),
      reducer: editorReducer,
      environment: MainEnvironment(
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    let image1 = image(color: .red, size: CGSize(width: 6, height: 4))
    let image2 = image(color: .blue, size: CGSize(width: 3, height: 6))

    store.assert(
      .send(.loadImage(image1)) {
        $0.canvas = CanvasState(
          size: .zero,
          image: image1,
          frame: CGRect(origin: .zero, size: image1.size)
        )
        $0.menu.isImageLoaded = true
      },
      .receive(.canvas(.scaleToFill)) {
        $0.canvas!.frame.origin = CGPoint(x: -24, y: -16)
        $0.canvas!.frame.size = CGSize(width: 48, height: 32)
      },
      .do {
        XCTAssertEqual(didSendSignals, [.loadImage(
          size: image1.size,
          scale: image1.scale
        )])
      },
      .send(.canvas(.updateSize(CGSize(width: 3, height: 4)))) {
        $0.canvas!.size = CGSize(width: 3, height: 4)
      },
      .receive(.canvas(.scaleToFill)) {
        $0.canvas!.frame.origin = CGPoint(x: -25.5, y: -16)
        $0.canvas!.frame.size = CGSize(width: 54, height: 36)
      },
      .send(.loadImage(image2)) {
        $0.canvas!.image = image2
        $0.canvas!.frame.origin = .zero
        $0.canvas!.frame.size = image2.size
      },
      .receive(.canvas(.scaleToFill)) {
        $0.canvas!.frame.origin = CGPoint(x: -16, y: -33)
        $0.canvas!.frame.size = CGSize(width: 35, height: 70)
      },
      .do {
        XCTAssertEqual(didSendSignals.count, 2)
        XCTAssertEqual(didSendSignals.last, .loadImage(
          size: image2.size,
          scale: image2.scale
        ))
      }
    )
  }

  func testExportingImageWhenNoImageLoaded() {
    var didSendSignals = [AppTelemetry.Signal]()
    let store = TestStore(
      initialState: EditorState(),
      reducer: editorReducer,
      environment: MainEnvironment(
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    store.assert(
      .send(.menu(.exportToLibrary)),
      .receive(.exportImage),
      .do {
        XCTAssertEqual(didSendSignals, [.exportToLibrary])
      }
    )
  }

  func testExportingImage() {
    var didRenderCanvas: [CanvasState] = []
    let renderedCanvas: UIImage = image(color: .blue, size: CGSize(width: 4, height: 6))
    let photoLibraryWriter = PhotoLibraryWriterDouble()
    var didSendSignals = [AppTelemetry.Signal]()
    let initialState = EditorState(
      canvas: CanvasState(
        size: CGSize(width: 4, height: 6),
        image: image(color: .red, size: CGSize(width: 40, height: 60)),
        frame: CGRect(
          origin: CGPoint(x: -5, y: -10),
          size: CGSize(width: 20, height: 20)
        )
      )
    )
    let store = TestStore(
      initialState: initialState,
      reducer: editorReducer,
      environment: MainEnvironment(
        renderCanvas: { canvas -> UIImage in
          didRenderCanvas.append(canvas)
          return renderedCanvas
        },
        photoLibraryWriter: photoLibraryWriter,
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    store.assert(
      .send(.menu(.exportToLibrary)),
      .receive(.exportImage),
      .do {
        XCTAssertEqual(didRenderCanvas, [initialState.canvas!])
        XCTAssertEqual(photoLibraryWriter.didWriteImages, [renderedCanvas])
        XCTAssertEqual(didSendSignals, [
          .exportToLibrary,
          .exportImage(
            size: initialState.canvas!.size,
            frame: initialState.canvas!.frame,
            blur: initialState.canvas!.blur,
            saturation: initialState.canvas!.saturation,
            hue: initialState.canvas!.hue
          )
        ])
        photoLibraryWriter.completion?(nil)
      },
      .receive(.didExportImage) {
        $0.isPresentingAlert = .exportSuccess
      },
      .do {
        XCTAssertEqual(didSendSignals.count, 3)
        XCTAssertEqual(didSendSignals.last, .didExportImage)
      },
      .send(.dismissAlert) {
        $0.isPresentingAlert = nil
      }
    )
  }

  func testExportingImageFailure() {
    let error = NSError(domain: "test", code: 1234, userInfo: nil)
    let photoLibraryWriter = PhotoLibraryWriterDouble()
    var didSendSignals = [AppTelemetry.Signal]()
    let initialState = EditorState(
      canvas: CanvasState(size: .zero, image: UIImage(), frame: .zero)
    )
    let store = TestStore(
      initialState: initialState,
      reducer: editorReducer,
      environment: MainEnvironment(
        renderCanvas: { _ in UIImage() },
        photoLibraryWriter: photoLibraryWriter,
        appTelemetry: AppTelemetry(send: {
          didSendSignals.append($0)
        })
      )
    )

    store.assert(
      .send(.menu(.exportToLibrary)),
      .receive(.exportImage),
      .do {
        XCTAssertEqual(didSendSignals, [
          .exportToLibrary,
          .exportImage(
            size: initialState.canvas!.size,
            frame: initialState.canvas!.frame,
            blur: initialState.canvas!.blur,
            saturation: initialState.canvas!.saturation,
            hue: initialState.canvas!.hue
          )
        ])
        photoLibraryWriter.completion?(error)
      },
      .receive(.didFailExportingImage) {
        $0.isPresentingAlert = .exportFailure
      },
      .do {
        XCTAssertEqual(didSendSignals.count, 3)
        XCTAssertEqual(didSendSignals.last, .didFailExportingImage)
      },
      .send(.dismissAlert) {
        $0.isPresentingAlert = nil
      }
    )
  }

  func testMenuUpdateFilters() {
    let store = TestStore(
      initialState: EditorState(
        canvas: CanvasState(size: .zero, image: UIImage(), frame: .zero)
      ),
      reducer: editorReducer,
      environment: MainEnvironment()
    )

    store.assert(
      .send(.menu(.updateBlur(0.66))) {
        $0.canvas?.blur = 0.66
      },
      .send(.menu(.updateSaturation(2))) {
        $0.canvas?.saturation = 2
      },
      .send(.menu(.updateHue(120))) {
        $0.canvas?.hue = 120
      }
    )
  }

  private func image(color: UIColor, size: CGSize) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { context in
      color.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
  }
}

private class PhotoLibraryWriterDouble: PhotoLibraryWriting {
  private(set) var didWriteImages: [UIImage] = []
  private(set) var completion: ((Error?) -> Void)?

  func write(image: UIImage, completion: @escaping (Error?) -> Void) {
    didWriteImages.append(image)
    self.completion = completion
  }
}
