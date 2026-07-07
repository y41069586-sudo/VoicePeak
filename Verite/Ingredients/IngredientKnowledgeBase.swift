import SwiftUI

/// A bundled, offline knowledge base classifying common INCI ingredients. This is
/// intentionally curated (not exhaustive) — enough to give honest, useful signal
/// on most products without a network call. Extended over time.
enum IngredientKnowledgeBase {

    struct Entry: @unchecked Sendable {
        let classes: [IngredientClass]
        let noteKey: LocalizedStringKey?
        let comedogenic: Int?
        init(_ classes: [IngredientClass], note: LocalizedStringKey? = nil, comedogenic: Int? = nil) {
            self.classes = classes
            self.noteKey = note
            self.comedogenic = comedogenic
        }
    }

    /// Normalized key for lookup (lowercase, no periods, common alias folding).
    static func normalizeKey(_ name: String) -> String {
        var key = INCIParser.normalize(name)
        for (alias, canonical) in aliases where key == alias { key = canonical }
        return key
    }

    static func lookup(_ name: String) -> Entry? {
        let key = normalizeKey(name)
        if let exact = entries[key] { return exact }
        // Pattern fallbacks for families we don't enumerate exhaustively.
        for (needle, entry) in patterns where key.contains(needle) { return entry }
        return nil
    }

    // MARK: Alias folding (INCI ⇄ common name)

    private static let aliases: [String: String] = [
        "water": "aqua",
        "hyaluronic acid": "sodium hyaluronate",
        "vitamin c": "ascorbic acid",
        "l-ascorbic acid": "ascorbic acid",
        "vitamin e": "tocopherol",
        "parfum/fragrance": "parfum",
        "fragrance": "parfum",
        "alcohol denat": "alcohol denat.",
        "denatured alcohol": "alcohol denat.",
        "cocos nucifera oil": "coconut oil",
        "butyrospermum parkii butter": "shea butter",
        "centella asiatica extract": "centella asiatica",
        // Latin/INCI ⇄ canonical entry
        "simmondsia chinensis seed oil": "jojoba oil",
        "argania spinosa kernel oil": "argan oil",
        "rosa canina fruit oil": "rosehip oil",
        "rosa moschata seed oil": "rosehip oil",
        "ricinus communis seed oil": "castor oil",
        "helianthus annuus seed oil": "sunflower seed oil",
        "olea europaea fruit oil": "olive oil",
        "persea gratissima oil": "avocado oil",
        "theobroma cacao seed butter": "cocoa butter",
        "mangifera indica seed butter": "mango butter",
        "paraffinum liquidum": "mineral oil",
        "melaleuca alternifolia leaf oil": "tea tree oil",
        "lavandula angustifolia oil": "lavender oil",
        "mentha piperita oil": "peppermint oil",
        "aloe vera": "aloe barbadensis leaf juice",
        // Common names ⇄ INCI
        "vitamin b3": "niacinamide",
        "nicotinamide": "niacinamide",
        "vitamin b5": "panthenol",
        "provitamin b5": "panthenol",
        "caprylic capric triglyceride": "caprylic/capric triglyceride",
    ]

    // MARK: Exact entries

    private static let entries: [String: Entry] = [
        // Bases / preservatives
        "aqua": Entry([.other], note: "ingredient.note.water"),
        "glycerin": Entry([.humectant], note: "ingredient.note.glycerin", comedogenic: 0),
        "phenoxyethanol": Entry([.other]),
        "propylene glycol": Entry([.humectant], comedogenic: 0),
        "pentylene glycol": Entry([.humectant], comedogenic: 0),
        "sodium pca": Entry([.humectant], comedogenic: 0),
        "urea": Entry([.humectant]),

        // Actives
        "niacinamide": Entry([.active], note: "ingredient.note.niacinamide", comedogenic: 0),
        "retinol": Entry([.active, .irritant], note: "ingredient.note.retinol", comedogenic: 0),
        "ascorbic acid": Entry([.active], note: "ingredient.note.vitaminC", comedogenic: 0),
        "sodium hyaluronate": Entry([.humectant, .active], note: "ingredient.note.hyaluronic", comedogenic: 0),
        "salicylic acid": Entry([.active, .irritant], note: "ingredient.note.salicylic", comedogenic: 0),
        "glycolic acid": Entry([.active, .irritant], note: "ingredient.note.glycolic", comedogenic: 0),
        "lactic acid": Entry([.active, .humectant], comedogenic: 0),
        "azelaic acid": Entry([.active], comedogenic: 0),
        "benzoyl peroxide": Entry([.active, .irritant]),
        "centella asiatica": Entry([.active], note: "ingredient.note.cica"),
        "panthenol": Entry([.humectant], comedogenic: 0),
        "allantoin": Entry([.other], comedogenic: 0),
        "tocopherol": Entry([.emollient, .active], comedogenic: 2),
        "zinc pca": Entry([.other], comedogenic: 0),

        // Emollients / occlusives
        "dimethicone": Entry([.emollient], comedogenic: 1),
        "squalane": Entry([.emollient], comedogenic: 0),
        "cetyl alcohol": Entry([.emollient], comedogenic: 2),
        "cetearyl alcohol": Entry([.emollient], comedogenic: 2),
        "stearyl alcohol": Entry([.emollient], comedogenic: 2),
        "shea butter": Entry([.emollient], comedogenic: 1),
        "coconut oil": Entry([.emollient, .comedogenic], comedogenic: 4),
        "isopropyl myristate": Entry([.emollient, .comedogenic], comedogenic: 5),

        // Alcohols (drying) — distinct from fatty alcohols above
        "alcohol denat.": Entry([.alcohol], note: "ingredient.note.alcoholDenat"),
        "ethanol": Entry([.alcohol]),

        // Fragrance / allergens
        "parfum": Entry([.fragrance], note: "ingredient.note.fragrance"),
        "limonene": Entry([.fragrance, .irritant]),
        "linalool": Entry([.fragrance, .irritant]),
        "citronellol": Entry([.fragrance, .irritant]),
        "geraniol": Entry([.fragrance, .irritant]),
        "citral": Entry([.fragrance, .irritant]),
        "menthol": Entry([.irritant, .fragrance]),
        "citrus limon peel oil": Entry([.fragrance, .irritant]),

        // ── Extended set (v1.1) ────────────────────────────────────────────
        // Curated common INCI so real products classify instead of falling to
        // "unknown". New entries carry classes + comedogenic only (no note key)
        // so they don't depend on unlocalized strings; the UI shows the class
        // description as the explanation.

        // Humectants / hydrators
        "betaine": Entry([.humectant], comedogenic: 0),
        "butylene glycol": Entry([.humectant], comedogenic: 0),
        "propanediol": Entry([.humectant], comedogenic: 0),
        "sodium lactate": Entry([.humectant], comedogenic: 0),
        "trehalose": Entry([.humectant]),
        "aloe barbadensis leaf juice": Entry([.humectant]),
        "saccharide isomerate": Entry([.humectant]),
        "hydroxyethyl urea": Entry([.humectant]),
        "caprylyl glycol": Entry([.humectant, .other], comedogenic: 0),
        "beta-glucan": Entry([.humectant, .active]),
        "ectoin": Entry([.humectant, .active]),

        // Actives
        "bakuchiol": Entry([.active]),
        "tranexamic acid": Entry([.active]),
        "alpha-arbutin": Entry([.active]),
        "arbutin": Entry([.active]),
        "kojic acid": Entry([.active]),
        "mandelic acid": Entry([.active, .irritant], comedogenic: 0),
        "gluconolactone": Entry([.active], comedogenic: 0),
        "ferulic acid": Entry([.active]),
        "resveratrol": Entry([.active]),
        "adenosine": Entry([.active]),
        "caffeine": Entry([.active]),
        "madecassoside": Entry([.active]),
        "ceramide np": Entry([.emollient, .active]),
        "retinyl palmitate": Entry([.active], comedogenic: 1),
        "retinal": Entry([.active, .irritant]),
        "retinaldehyde": Entry([.active, .irritant]),
        "hydroxypinacolone retinoate": Entry([.active]),
        "ascorbyl glucoside": Entry([.active]),
        "sodium ascorbyl phosphate": Entry([.active]),
        "magnesium ascorbyl phosphate": Entry([.active]),
        "tetrahexyldecyl ascorbate": Entry([.active], comedogenic: 1),
        "3-o-ethyl ascorbic acid": Entry([.active]),

        // Emollients / oils / butters / occlusives
        "caprylic/capric triglyceride": Entry([.emollient], comedogenic: 1),
        "jojoba oil": Entry([.emollient], comedogenic: 2),
        "argan oil": Entry([.emollient], comedogenic: 0),
        "rosehip oil": Entry([.emollient], comedogenic: 1),
        "marula oil": Entry([.emollient], comedogenic: 1),
        "castor oil": Entry([.emollient], comedogenic: 1),
        "sunflower seed oil": Entry([.emollient], comedogenic: 0),
        "olive oil": Entry([.emollient], comedogenic: 2),
        "avocado oil": Entry([.emollient], comedogenic: 3),
        "cocoa butter": Entry([.emollient, .comedogenic], comedogenic: 4),
        "mango butter": Entry([.emollient], comedogenic: 2),
        "petrolatum": Entry([.emollient], comedogenic: 0),
        "mineral oil": Entry([.emollient], comedogenic: 1),
        "lanolin": Entry([.emollient], comedogenic: 2),
        "glyceryl stearate": Entry([.emollient], comedogenic: 1),
        "cetyl esters": Entry([.emollient], comedogenic: 2),
        "isopropyl palmitate": Entry([.emollient, .comedogenic], comedogenic: 4),
        "isononyl isononanoate": Entry([.emollient], comedogenic: 2),
        "myristyl myristate": Entry([.emollient, .comedogenic], comedogenic: 5),
        "behenyl alcohol": Entry([.emollient], comedogenic: 1),
        "myristyl alcohol": Entry([.emollient], comedogenic: 3),
        "tocopheryl acetate": Entry([.emollient, .active], comedogenic: 2),

        // Silicones
        "cyclopentasiloxane": Entry([.emollient], comedogenic: 0),
        "cyclohexasiloxane": Entry([.emollient], comedogenic: 0),
        "dimethiconol": Entry([.emollient], comedogenic: 1),
        "phenyl trimethicone": Entry([.emollient], comedogenic: 0),

        // Surfactants (mild → other; harsh → irritant)
        "sodium laureth sulfate": Entry([.other]),
        "sodium lauryl sulfate": Entry([.irritant]),
        "cocamidopropyl betaine": Entry([.other]),
        "coco-glucoside": Entry([.other]),
        "decyl glucoside": Entry([.other]),
        "lauryl glucoside": Entry([.other]),
        "sodium cocoyl isethionate": Entry([.other]),

        // Preservatives / functional / pH — benign, shown as neutral
        "ethylhexylglycerin": Entry([.other]),
        "sodium benzoate": Entry([.other]),
        "potassium sorbate": Entry([.other]),
        "chlorphenesin": Entry([.other]),
        "benzyl alcohol": Entry([.other]),
        "disodium edta": Entry([.other]),
        "tetrasodium edta": Entry([.other]),
        "xanthan gum": Entry([.other]),
        "carbomer": Entry([.other]),
        "sodium hydroxide": Entry([.other]),
        "citric acid": Entry([.other]),
        "triethanolamine": Entry([.other]),
        "hydroxyethylcellulose": Entry([.other]),
        "sodium chloride": Entry([.other]),

        // UV filters (mineral filters get a light comedogenic note)
        "zinc oxide": Entry([.other], comedogenic: 1),
        "titanium dioxide": Entry([.other], comedogenic: 1),
        "butyl methoxydibenzoylmethane": Entry([.other]),
        "octocrylene": Entry([.other]),
        "homosalate": Entry([.other]),
        "ethylhexyl methoxycinnamate": Entry([.other]),
        "ethylhexyl salicylate": Entry([.other]),

        // Fragrance allergens (EU-labelled) + botanical/essential oils
        "eugenol": Entry([.fragrance, .irritant]),
        "isoeugenol": Entry([.fragrance, .irritant]),
        "coumarin": Entry([.fragrance]),
        "benzyl salicylate": Entry([.fragrance]),
        "benzyl benzoate": Entry([.fragrance]),
        "hexyl cinnamal": Entry([.fragrance]),
        "amyl cinnamal": Entry([.fragrance]),
        "cinnamal": Entry([.fragrance, .irritant]),
        "hydroxycitronellal": Entry([.fragrance]),
        "farnesol": Entry([.fragrance]),
        "alpha-isomethyl ionone": Entry([.fragrance]),
        "butylphenyl methylpropional": Entry([.fragrance]),
        "tea tree oil": Entry([.active, .irritant]),
        "lavender oil": Entry([.fragrance, .irritant]),
        "peppermint oil": Entry([.fragrance, .irritant]),
        "eucalyptus oil": Entry([.fragrance, .irritant]),
    ]

    // MARK: Pattern fallbacks (checked only on exact miss)

    private static let patterns: [(String, Entry)] = [
        // Specific families first (first substring match wins).
        ("essential oil", Entry([.fragrance, .irritant])),
        ("tea tree", Entry([.active, .irritant])),
        ("melaleuca", Entry([.active, .irritant])),
        ("lavandula", Entry([.fragrance, .irritant])),
        ("lavender", Entry([.fragrance, .irritant])),
        ("peppermint", Entry([.fragrance, .irritant])),
        ("eucalyptus", Entry([.fragrance, .irritant])),
        ("citrus", Entry([.fragrance, .irritant])),
        ("ceramide", Entry([.emollient, .active])),
        ("hyaluron", Entry([.humectant, .active])),
        ("tocopher", Entry([.emollient, .active], comedogenic: 2)),
        ("ascorb", Entry([.active])),
        ("niacinamide", Entry([.active])),
        ("panthenol", Entry([.humectant])),
        ("jojoba", Entry([.emollient], comedogenic: 2)),
        ("argan", Entry([.emollient])),
        ("shea", Entry([.emollient], comedogenic: 1)),
        ("sunflower", Entry([.emollient])),
        ("helianthus", Entry([.emollient])),
        ("olea europaea", Entry([.emollient], comedogenic: 2)),
        ("ricinus", Entry([.emollient], comedogenic: 1)),
        ("avocado", Entry([.emollient], comedogenic: 3)),
        ("persea gratissima", Entry([.emollient], comedogenic: 3)),
        ("cocoa", Entry([.emollient, .comedogenic], comedogenic: 4)),
        ("cacao", Entry([.emollient, .comedogenic], comedogenic: 4)),
        ("dimethicone", Entry([.emollient], comedogenic: 1)),
        ("siloxane", Entry([.emollient])),
        ("glucoside", Entry([.other])),
        ("betaine", Entry([.humectant])),
        ("edta", Entry([.other])),
        ("hydroxide", Entry([.other])),
        // Existing generic fallbacks (kept last so they never shadow the above).
        ("parfum", Entry([.fragrance], note: "ingredient.note.fragrance")),
        ("fragrance", Entry([.fragrance], note: "ingredient.note.fragrance")),
        ("alcohol denat", Entry([.alcohol], note: "ingredient.note.alcoholDenat")),
        ("peg-", Entry([.other])),
        ("glycol", Entry([.humectant])),
    ]
}
