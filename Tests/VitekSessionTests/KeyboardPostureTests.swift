import Testing
import VitekSession

@Suite struct KeyboardPostureTests {
    @Test func classifiesOuterCoverStandardAndMultitaskingPanes() {
        let cover = KeyboardPosture.classify(
            containerWidth: 360,
            containerHeight: 300,
            screenWidth: 360,
            screenHeight: 780,
            isVerticalCompact: false
        )
        #expect(cover == .coverCompact)
        #expect(!cover.allowsSplit)
        #expect(cover.allowsOneHanded)
        #expect(cover.edgeTouchAssistRatio == 0.27)

        let portrait = KeyboardPosture.classify(
            containerWidth: 393,
            containerHeight: 300,
            screenWidth: 393,
            screenHeight: 852,
            isVerticalCompact: false
        )
        #expect(portrait == .standardPortrait)
        #expect(!portrait.allowsSplit)
        #expect(portrait.edgeTouchAssistRatio == 0.22)

        // Side-by-side Split View on an unfolded iPhone Duo keeps screen >= 500x620 while container drops to ~368pt.
        let dualPane = KeyboardPosture.classify(
            containerWidth: 368,
            containerHeight: 300,
            screenWidth: 744,
            screenHeight: 820,
            isVerticalCompact: false
        )
        #expect(dualPane == .dualPaneCompact)
        #expect(!dualPane.allowsSplit)
        #expect(dualPane.allowsOneHanded)
    }

    @Test func classifiesUnfoldedDuoLandscapeAndTabletop() {
        let unfolded = KeyboardPosture.classify(
            containerWidth: 744,
            containerHeight: 320,
            screenWidth: 744,
            screenHeight: 820,
            isVerticalCompact: false
        )
        #expect(unfolded == .duoUnfoldedBook)
        #expect(unfolded.allowsSplit)
        #expect(unfolded.supportsUtilityDeck)
        #expect(unfolded.usesInteractiveCenterBridge(for: 744))
        let bridgeWidth = unfolded.recommendedBridgeWidth(for: 744)
        #expect(bridgeWidth >= 116 && bridgeWidth <= 184)

        let landscape = KeyboardPosture.classify(
            containerWidth: 852,
            containerHeight: 210,
            screenWidth: 852,
            screenHeight: 393,
            isVerticalCompact: true
        )
        #expect(landscape == .phoneLandscape)
        #expect(landscape.allowsSplit)
        #expect(!landscape.usesInteractiveCenterBridge(for: 852))

        let tabletop = KeyboardPosture.classify(
            containerWidth: 1024,
            containerHeight: 340,
            screenWidth: 1024,
            screenHeight: 768,
            isVerticalCompact: false
        )
        #expect(tabletop == .tabletopWide)
        #expect(tabletop.allowsSplit)
        #expect(tabletop.supportsUtilityDeck)
        #expect(tabletop.usesInteractiveCenterBridge(for: 1024))
    }
}
