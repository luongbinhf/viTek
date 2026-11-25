/// English words whose keys Telex would change by adding or cancelling a mark.
public enum EnglishWords {
    // Match a whole known spelling after Telex undo. The literal composer keeps subsequent letters.
    private static let repeatedToneKeyWords: Set<String> = [
        "affair", "affect", "affiliate", "affirm", "afflict", "afford", "affront", "array", "arrest",
        "arrival", "arrive", "arrogant", "arrow", "assembly", "assent", "assert", "assess", "asset",
        "assign", "assist", "associate", "association", "assort", "assume", "assure", "baffle", "barrel",
        "barren", "barrier", "bassist", "bassoon", "berries", "berry", "borrow", "boss", "buffalo",
        "buffer", "buffet", "buffoon", "burrow", "carried", "carrier", "carrot", "carry", "cassette",
        "cherries", "cherry", "chess", "chiffon", "cocoon", "coffee", "coffin", "corral", "correct",
        "corresponding", "corridor", "corrupt", "currant", "currency", "current", "curriculum", "curry",
        "daddy", "deepen", "derrick", "dessert", "differ", "difficult", "diffuse", "dissect", "dissent",
        "duffel", "effect", "efficiency", "efficient", "effort", "errand", "errant", "erratic", "error",
        "essay", "essential", "esteem", "garret", "garrison", "gossip", "harry", "hassle", "herring",
        "horrible", "horrid", "horrify", "horror", "hurrah", "hurricane", "hurried", "hurry", "iffy",
        "irritate", "issue", "issues", "issuing", "kerry", "kiss", "larry", "less", "lessen", "lesson",
        "lorry", "loss", "marriage", "married", "marrow", "marry", "mass", "massage", "masses", "massive",
        "merrily", "merry", "mess", "message", "messenger", "messy", "mirror", "miss", "missile",
        "missing", "mission", "misstep", "monsoon", "moss", "mossy", "muffin", "mussel", "myrrh",
        "narrate", "narrow", "necessarily", "necessary", "offbeat", "offend", "offense", "offensive",
        "offer", "office", "official", "offset", "opossum", "parrot", "parry", "pass", "passage",
        "passes", "passing", "passion", "passive", "passkey", "password", "perry", "possum",
        "possibility", "possible", "possibly", "puff", "puffin", "puffy", "purr", "pussy", "quarrel",
        "quarry", "russet", "russia", "saffron", "sassy", "session", "sierra", "sissy", "sorrow",
        "sorry", "suffer", "sufficient", "surround", "swiss", "taffy", "tariff", "tassel", "terrace",
        "terrain", "terrible", "terrier", "terrific", "terrify", "territory", "terror", "terry",
        "tiffany", "tissue", "toffee", "tomorrow", "torrent", "toss", "traffic", "turret", "tussle",
        "vessel", "waffle", "warrant", "warren", "warrior", "worried", "worries", "worry",
    ]
    private static let longestRepeatedWord = repeatedToneKeyWords.map(\.utf8.count).max() ?? 0

    static func keepsRepeatedToneKey(in keys: [Character]) -> Bool {
        // A literal token can grow indefinitely. Only form a lookup string while it can match.
        guard let lower = ASCII.lowercasedString(keys, maxLength: longestRepeatedWord) else { return false }
        return repeatedToneKeyWords.contains(lower)
    }

    /// True when a finished Telex word should stay as typed. The last key must be a plain letter:
    /// a Vietnamese typist ending on a tone or mark key (`tets`, `as`, `too`) means Vietnamese.
    static func keepsKeys(_ keys: String, options: EngineOptions) -> Bool {
        guard options.keepEnglishWords, options.inputMethod == .telex,
              let last = keys.utf8.last, options.inputMethod.action(for: last, options: options) == nil
        else { return false }
        return words.contains(keys.lowercased())
    }

    static let words = Set(list.split(separator: "\n").map(String.init)).union(repeatedToneKeyWords)

    /// The listed words, sorted, for showing to the user.
    public static let all = words.sorted()

    /// True when `word` is in the built-in common English word list (case-insensitive).
    public static func contains(_ word: String) -> Bool {
        words.contains(word.lowercased())
    }
}
