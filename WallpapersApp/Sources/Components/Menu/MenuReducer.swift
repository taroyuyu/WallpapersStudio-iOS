import ComposableArchitecture

typealias MenuReducer = Reducer<MenuState, MenuAction, Void>

let menuReducer = MenuReducer { state, action, _ in
  switch action {
  case .importFromLibrary:
    return .none

  case .exportToLibrary:
    return .none
  }
}