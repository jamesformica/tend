import Foundation

// Intermediate frames for the Wilting → Flowering recovery animation.
// Played in sequence over ~0.8s when the user waters a wilting plant.
// Both frames are 8 lines and use the same closing-`"""` indent as PlantStage.frame,
// so the pot sits at the same column across the whole animation — no layout shift.
enum RecoveryFrame: CaseIterable {
    case step1, step2

    var frame: String {
        switch self {
        case .step1:
            return """

                  _
                _(_)_
                 (_)
             (\\|
             _ |__
            ['____]
             \\___/
            """
        case .step2:
            return """
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
    }
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
