import struct CoreGraphics.CGFloat

enum MenuAction: Equatable {
  case importFromLibrary
  case exportToLibrary
  case updateBlur(CGFloat)
}
