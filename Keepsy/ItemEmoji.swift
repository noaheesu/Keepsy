/// Picks an emoji from an item's name, so the list has a picture without anyone taking photos.
enum ItemEmoji {
    /// The longest keyword found in the name wins, so "선크림" beats "크림"; on a tie the later one,
    /// as the last word names the thing ("배추김치" is kimchi).
    static func guess(for name: String) -> String? {
        let name = name.lowercased()
        var best: (emoji: String, length: Int, end: String.Index)?
        for (emoji, keywords) in table {
            for keyword in keywords {
                guard let end = name.range(of: keyword, options: .backwards)?.upperBound else { continue }
                if let best, (keyword.count, end) <= (best.length, best.end) { continue }
                best = (emoji, keyword.count, end)
            }
        }
        return best?.emoji
    }

    private static let table: [(String, [String])] = [
        // Dairy and eggs
        ("🥛", ["우유", "milk", "두유", "soy milk", "생크림", "휘핑", "whipping"]),
        ("🥚", ["달걀", "계란", "egg"]),
        ("🧀", ["치즈", "cheese"]),
        ("🧈", ["버터", "butter", "마가린"]),
        ("🍦", ["요거트", "요구르트", "yogurt", "yoghurt", "아이스크림", "ice cream"]),
        // Produce
        ("🍎", ["사과", "apple"]),
        ("🍌", ["바나나", "banana"]),
        ("🍊", ["귤", "오렌지", "orange", "한라봉", "mandarin"]),
        ("🍋", ["레몬", "lemon", "라임", "lime"]),
        ("🍇", ["포도", "grape", "샤인머스캣"]),
        ("🍓", ["딸기", "strawberr"]),
        ("🫐", ["블루베리", "blueberr", "berries"]),
        ("🍑", ["복숭아", "peach"]),
        ("🍐", ["배", "pear"]),
        ("🍉", ["수박", "watermelon"]),
        ("🍈", ["참외", "멜론", "melon"]),
        ("🥝", ["키위", "kiwi"]),
        ("🍍", ["파인애플", "pineapple"]),
        ("🥭", ["망고", "mango"]),
        ("🍅", ["토마토", "tomato"]),
        ("🥑", ["아보카도", "avocado"]),
        ("🥬", ["시금치", "spinach", "배추", "상추", "양배추", "cabbage", "lettuce", "깻잎", "청경채", "kale"]),
        ("🥦", ["브로콜리", "broccoli"]),
        ("🍆", ["가지", "eggplant", "aubergine"]),
        ("🥒", ["오이", "cucumber", "애호박", "zucchini"]),
        ("🥕", ["당근", "carrot"]),
        ("🥔", ["감자", "potato"]),
        ("🍠", ["고구마", "sweet potato"]),
        ("🧅", ["양파", "onion"]),
        ("🧄", ["마늘", "garlic"]),
        ("🌶️", ["고추", "pepper", "chili"]),
        ("🫑", ["피망", "파프리카", "bell pepper"]),
        ("🌽", ["옥수수", "corn"]),
        ("🍄", ["버섯", "mushroom"]),
        ("🌿", ["대파", "쪽파", "부추", "허브", "herb", "basil", "고수", "scallion", "green onion"]),
        ("🫚", ["생강", "ginger"]),
        // Meat and fish
        ("🥩", ["소고기", "쇠고기", "돼지고기", "삼겹살", "목살", "고기", "beef", "pork", "steak", "meat"]),
        ("🍗", ["닭", "chicken"]),
        ("🥓", ["베이컨", "bacon", "햄", "ham", "스팸", "spam"]),
        ("🌭", ["소시지", "sausage", "핫도그", "hot dog"]),
        ("🐟", ["생선", "고등어", "연어", "갈치", "참치", "fish", "salmon", "tuna", "cod"]),
        ("🦐", ["새우", "shrimp", "prawn"]),
        ("🦑", ["오징어", "squid", "낙지", "문어"]),
        ("🦪", ["굴", "조개", "oyster", "clam", "홍합", "mussel"]),
        // Pantry and cooked
        ("🍞", ["빵", "식빵", "bread", "toast", "베이글", "bagel"]),
        ("🥐", ["크루아상", "croissant"]),
        ("🍚", ["쌀", "밥", "rice", "햇반"]),
        ("🍜", ["라면", "ramen", "noodle", "국수", "우동", "udon", "냉면"]),
        ("🍝", ["파스타", "스파게티", "pasta", "spaghetti"]),
        ("🥟", ["만두", "dumpling"]),
        ("🍕", ["피자", "pizza"]),
        ("🧊", ["얼음", "ice"]),
        ("🫙", ["김치", "kimchi", "장아찌", "피클", "pickle", "잼", "jam", "소스", "sauce", "케첩", "ketchup", "마요", "mayo",
                "된장", "고추장", "간장", "soy sauce", "쌈장", "드레싱", "dressing"]),
        ("🧂", ["소금", "salt", "설탕", "sugar", "후추"]),
        ("🫒", ["올리브", "olive", "식용유", "참기름", "들기름", "oil"]),
        ("🍯", ["꿀", "honey", "조청", "시럽", "syrup"]),
        ("🥫", ["통조림", "참치캔", "canned", " can"]),
        ("🌾", ["밀가루", "flour", "부침가루", "튀김가루"]),
        ("🥣", ["시리얼", "cereal", "그래놀라", "granola", "오트", "oat"]),
        ("🥜", ["땅콩", "peanut", "견과", "nut", "아몬드", "almond", "호두", "walnut"]),
        ("🫘", ["콩", "bean"]),
        ("🍪", ["과자", "쿠키", "cookie", "snack", "비스킷", "biscuit", "크래커", "cracker"]),
        ("🍫", ["초콜릿", "초코", "chocolate"]),
        ("🍰", ["케이크", "cake", "디저트", "dessert"]),
        ("🍙", ["김밥", "주먹밥", "onigiri", "도시락"]),
        ("🌊", ["seaweed", "미역", "다시마", "구운김", "조미김"]),
        ("🍲", ["국", "찌개", "stew", "soup", "반찬"]),
        // Drinks
        ("🧃", ["주스", "juice"]),
        ("☕", ["커피", "coffee", "원두"]),
        ("🍵", ["녹차", "홍차", "보리차", "옥수수차", "tea"]),
        ("🥤", ["콜라", "사이다", "탄산", "soda", "cola", "음료"]),
        ("💧", ["생수", "water"]),
        ("🍺", ["맥주", "beer"]),
        ("🍷", ["와인", "wine"]),
        ("🍶", ["소주", "막걸리", "soju", "sake"]),
        // Bathroom, health, household
        ("🪥", ["칫솔", "치약", "toothpaste", "toothbrush", "가글", "mouthwash"]),
        ("🧴", ["샴푸", "shampoo", "린스", "컨디셔너", "conditioner", "로션", "lotion", "선크림", "선블록", "sunscreen",
                "바디워시", "body wash", "크림", "cream", "클렌저", "cleanser", "토너", "toner", "세럼", "serum", "핸드워시", "hand wash"]),
        ("🧼", ["비누", "soap"]),
        ("💄", ["립스틱", "lipstick", "화장품", "파운데이션", "foundation", "쿠션", "마스카라", "mascara", "makeup"]),
        ("🪒", ["면도", "razor", "shaving"]),
        ("🧻", ["휴지", "화장지", "toilet paper", "키친타월", "paper towel", "물티슈", "wipes", "티슈", "tissue"]),
        ("💊", ["약", "알약", "pill", "tablet", "비타민", "vitamin", "영양제", "supplement", "진통제", "감기약", "medicine", "유산균", "probiotic"]),
        ("🩹", ["밴드", "반창고", "bandage", "band-aid", "파스"]),
        ("🧺", ["세제", "detergent", "섬유유연제", "softener", "표백제", "bleach"]),
        ("🧽", ["수세미", "sponge", "주방세제", "dish soap"]),
        ("🗑️", ["쓰레기봉투", "trash bag", "종량제"]),
        ("🔋", ["건전지", "배터리", "battery"]),
        ("💡", ["전구", "bulb"]),
        ("🐶", ["사료", "pet food", "dog food", "강아지"]),
        ("🐱", ["고양이", "cat food", "모래", "litter"]),
        ("🍼", ["분유", "formula", "이유식", "baby food"]),
        ("👶", ["기저귀", "diaper"]),
    ]
}
