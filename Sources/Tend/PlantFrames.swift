import Foundation

// Intermediate frames for the Wilting → Flowering recovery animation.
// Played in sequence over ~1.2s when the user waters a wilting plant.
enum RecoveryFrame {
    static let step1: String = """


         __
       _(_)_
        (_)
      (\\|
      _ |__
     ['____]
      \\___/
    """

    static let step2: String = """
         _
       _(_)_
      (_)*(_)
        (_)
      (\\|
      _ |__
     ['____]
      \\___/
    """
}

enum PlantStage: String, CaseIterable {
    case seedling
    case youngling
    case growing
    case flowering
    case wilting
    case dead

    var isGrowing: Bool {
        switch self {
        case .seedling, .youngling, .growing: return true
        case .flowering, .wilting, .dead: return false
        }
    }

    var frame: String {
        switch self {
        case .seedling:
            return """






            ['____]
             \\___/
            """
        case .youngling:
            return """




                ,
             (\\|__
            ['____]
             \\___/
            """
        case .growing:
            return """



              (\\
               |/)
             _\\|__
            ['____]
             \\___/
            """
        case .flowering:
            return """
                  _
                _(_)_
               (_)*(_)
                /(_)
             (\\|
             _ |__
            ['____]
             \\___/
            """
        case .wilting:
            return """


                 __
              _ /(_)
             (/|  `
             _ |__
            ['____]
             \\___/
            """
        case .dead:
            return """



              ___
             |rip|
             | __|
            ['____]
             \\___/
            """
        }
    }
}
