/// Client-side Urdu / Roman Urdu overlays for CDN content that ships English-only.
/// Remove entries once the remote JSON includes matching keys.

const announcementOverlays = <String, Map<String, Map<String, String>>>{
  'ann-001': {
    'title': {
      'ur': 'آئی او ایس ایپ جلد آ رہی ہے',
      'roman': 'iOS App Jald Aa Rahi Hai',
    },
    'body': {
      'ur': 'جلد ایپ اسٹور پر دستیاب ہوگی۔ جزاکم اللہ خیرًا۔',
      'roman': 'Jald App Store Par Dastiyab Hogi. JazakAllahu Khayran.',
    },
  },
};

const benefitTextOverlays = <String, Map<String, String>>{
  'benefit-001': {
    'ur':
        'جو شخص اس بات کو جانتے ہوئے وفات پائے کہ اللہ کے سوا کوئی معبود نہیں، وہ جنت میں داخل ہوگا۔',
    'roman':
        'Jo shakhs is baat ko jaante hue wafaat paaye ke Allah ke siwa koi ma\'bood nahin, woh Jannat mein dakhil hoga.',
  },
  'benefit-002': {
    'ur': 'بہترین ذکر یہ ہے: لا إله إلا الله (اللہ کے سوا کوئی معبود نہیں)۔',
    'roman':
        'Behtareen zikr yeh hai: La ilaha illallah (Allah ke siwa koi ma\'bood nahin).',
  },
  'benefit-003': {
    'ur': 'اللہ فرماتا ہے: میں اپنے بندے کے گمان کے مطابق ہوں۔',
    'roman': 'Allah farmata hai: Main apne bande ke gumaan ke mutabiq hoon.',
  },
  'benefit-004': {
    'ur':
        'اللہ کی عبادت اس طرح کرو گویا تم اسے دیکھ رہے ہو؛ اگر تم اسے نہیں دیکھ سکتے تو جان لو کہ وہ تمہیں دیکھ رہا ہے۔',
    'roman':
        'Allah ki ibadat is tarah karo goya tum use dekh rahe ho; agar tum use nahin dekh sakte to jaan lo ke woh tumhein dekh raha hai.',
  },
  'benefit-005': {
    'ur':
        'بہترین کلمات جو میں نے اور مجھ سے پہلے کے انبیاء نے کہے: لا إله إلا الله وحده لا شريك له۔',
    'roman':
        'Behtareen kalimaat jo maine aur mujh se pehle ke anbiya ne kahe: La ilaha illallah wahdahu la shareeka lahu.',
  },
  'benefit-006': {
    'ur': 'جو اللہ کے ساتھ شریک ٹھہرائے گا، اللہ اس پر جنت حرام کر دے گا۔',
    'roman':
        'Jo Allah ke saath shareek thehraaye ga, Allah us par Jannat haraam kar dega.',
  },
  'benefit-007': {
    'ur': 'مجھے پکارو، میں تمہاری دعا قبول کروں گا۔',
    'roman': 'Mujhe pukaro, main tumhari dua qubool karunga.',
  },
  'benefit-008': {
    'ur': 'جو اللہ پر بھروسہ کرے، وہ اس کے لیے کافی ہے۔',
    'roman': 'Jo Allah par bharosa kare, woh us ke liye kaafi hai.',
  },
  'benefit-009': {
    'ur': 'بے شک اللہ کے ذکر سے دلوں کو سکون ملتا ہے۔',
    'roman': 'Be-shak Allah ke zikr se dilon ko sukoon milta hai.',
  },
  'benefit-010': {
    'ur': 'ہم اس سے اس کی رگ گردن سے بھی زیادہ قریب ہیں۔',
    'roman': 'Hum us se us ki rag gardan se bhi zyada qareeb hain.',
  },
  'benefit-011': {
    'ur': 'علم حاصل کرنا ہر مسلمان پر فرض ہے۔',
    'roman': 'Ilm hasil karna har Musalman par farz hai.',
  },
  'benefit-012': {
    'ur':
        'جو علم کی تلاش میں کوئی راستہ چلتا ہے، اللہ اس کے لیے جنت کا راستہ آسان کرتا ہے۔',
    'roman':
        'Jo ilm ki talash mein koi raasta chalta hai, Allah us ke liye Jannat ka raasta aasaan kar deta hai.',
  },
  'benefit-013': {
    'ur': 'اللہ علم لوگوں سے چھین کر نہیں لیتا، بلکہ علماء کو اٹھا کر لیتا ہے۔',
    'roman':
        'Allah ilm ko logon se cheen kar nahin leta, balke ulama ko utha kar leta hai.',
  },
  'benefit-014': {
    'ur': 'دعا ہی عبادت ہے۔',
    'roman': 'Dua hi ibadat hai.',
  },
  'benefit-015': {
    'ur':
        'جو دن میں سو مرتبہ "سبحان اللہ وبحمدہ" کہے، اس کے گناہ مٹا دیے جاتے ہیں۔',
    'roman':
        'Jo din mein sau martaba "SubhanAllahi wa bihamdihi" kahe, us ke gunah mita diye jate hain.',
  },
  'benefit-016': {
    'ur':
        'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير۔',
    'roman':
        'La ilaha illallah wahdahu la shareeka lahu, lahu al-mulku wa lahu al-hamdu wa huwa ala kulli shay-in qadeer.',
  },
  'benefit-017': {
    'ur':
        'اے ابن آدم! اگر تیرے گناہ آسمان تک پہنچ جائیں پھر تو مجھ سے معافی مانگے تو میں تجھے معاف کر دوں گا۔',
    'roman':
        'Ae Ibn Adam! Agar tere gunah aasman tak pahunch jayein phir tu mujh se maafi maange to main tujhe maaf kar doonga.',
  },
  'benefit-018': {
    'ur': 'اے اللہ! تو سلامتی والا ہے اور تیری طرف سے سلامتی ہے۔',
    'roman': 'Ae Allah! Tu salamati wala hai aur teri taraf se salamati hai.',
  },
  'benefit-019': {
    'ur': 'بے شک اللہ خوبصورت ہے اور خوبصورتی کو پسند کرتا ہے۔',
    'roman': 'Be-shak Allah khoobsurat hai aur khoobsurti ko pasand karta hai.',
  },
  'benefit-020': {
    'ur': 'مضبوط مومن کمزور مومن سے بہتر اور اللہ کو زیادہ محبوب ہے۔',
    'roman':
        'Mazboot momin kamzor momin se behtar aur Allah ko zyada mehboob hai.',
  },
  'benefit-021': {
    'ur': 'علم سیکھو اور علم کے لیے سکون اور وقار سیکھو۔',
    'roman': 'Ilm seekho aur ilm ke liye sukoon aur waqar seekho.',
  },
  'benefit-022': {
    'ur':
        'جو سفر کا خوف رکھے صبح جلدی نکلتا ہے، اور جو صبح جلدی نکلتا ہے منزل تک پہنچ جاتا ہے۔',
    'roman':
        'Jo safar ka khauf rakhe subah jaldi nikalta hai, aur jo subah jaldi nikalta hai manzil tak pahunch jata hai.',
  },
  'benefit-023': {
    'ur': 'اللہ کو سب سے محبوب عمل وہ ہے جو مسلسل ہو، چاہے تھوڑا ہو۔',
    'roman':
        'Allah ko sab se mehboob amal woh hai jo musalsal ho, chahe thora ho.',
  },
  'benefit-024': {
    'ur':
        'جب میرے بندے مجھ سے پوچھیں تو میں قریب ہوں؛ میں دعا کرنے والے کی دعا کا جواب دیتا ہوں جب وہ مجھے پکارتا ہے۔',
    'roman':
        'Jab mere bande mujh se poochhen to main qareeb hoon; main dua karne wale ki dua ka jawab deta hoon jab woh mujhe pukarta hai.',
  },
  'benefit-025': {
    'ur':
        'اے ہمارے رب! ہمیں دنیا میں بھلائی دے اور آخرت میں بھلائی دے، اور ہمیں آگ کے عذاب سے بچا۔',
    'roman':
        'Ae hamare Rabb! Hamein dunya mein bhalaai de aur aakhirat mein bhalaai de, aur hamein aag ke azab se bacha.',
  },
  'benefit-026': {
    'ur': 'بے شک اعمال نیتوں سے ہیں۔',
    'roman': 'Be-shak a\'maal niyaton se hain.',
  },
  'benefit-027': {
    'ur': 'جہاں کہیں بھی ہو اللہ سے ڈرو۔',
    'roman': 'Jahan kahin bhi ho Allah se daro.',
  },
  'benefit-028': {
    'ur':
        'آدم کے ہر بیٹے سے خطا ہوتی ہے، اور گناہ کرنے والوں میں بہترین وہ ہیں جو توبہ کرتے ہیں۔',
    'roman':
        'Adam ke har bete se khata hoti hai, aur khata karne walon mein behtareen woh hain jo tawba karte hain.',
  },
  'benefit-029': {
    'ur': 'کسی بھی نیکی کو چھوٹا مت سمجھو۔',
    'roman': 'Kisi bhi neki ko chhota mat samjho.',
  },
  'benefit-030': {
    'ur':
        'ایمان کی ستر سے زائد شاخیں ہیں؛ سب سے بلند "لا إله إلا الله" کہنا ہے۔',
    'roman':
        'Iman ke sattar se zyada shakhein hain; sab se unchi "La ilaha illallah" kehna hai.',
  },
};
