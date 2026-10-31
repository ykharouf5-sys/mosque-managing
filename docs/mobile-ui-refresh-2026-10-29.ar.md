# تحسين واجهات Studentry للموبايل

## دراسة الوظائف والاتجاه

الجمهور طلاب طب الأسنان، والمهام الأساسية: متابعة مرضى ومواعيد اليوم، تنظيم المواد والمحاضرات والدرجات، وتسوق المستلزمات ومتابعة الطلبات. الحساب والصلاحيات والمزامنة والخادم خارج نطاق إعادة التصميم.

طبقنا مبدأ Jakob: يبقى شريط التنقل وأسماء الأقسام ومسارات الدخول مألوفة، البريد وكلمة المرور مع إظهارها واستعادتها، Google كخيار مستقل، وحوار تأكيد قبل الحذف. لا نضيف تسجيل Apple أو دخول ضيف لمجرد ظهورهما في المرجع، فهما ليسا مساري الدخول الحاليين. [مرجع NN/g](https://www.nngroup.com/articles/consistency-and-standards/).

## اتجاه التصميم قبل التنفيذ

- الفيروزي الأساسي `#1195A7` كما هو، أبيض الأزرار `#FFFFFF`، خلفية الرسوم `#E8F6F7`، نص `#1E293B`، نص ثانوي `#64748B`، خلفية التطبيق `#F8FBFC`.
- الاحتفاظ بخط التطبيق، عنوان واضح 24–28، متن 14–16، أزرار بارتفاع أدنى 48 ومحاذاة وسطية ودون تقليص النموذج كله بـFittedBox.
- الدخول: هوية ورسمة طالب الأسنان أعلى الشاشة، ثم ورقة بيضاء بزوايا علوية واسعة، عنوان ونموذج قابل للتمرير عند ظهور لوحة المفاتيح. الرئيسية: تحية ورسمة مختصرة، بيانات اليوم الحقيقية، ثم الوصول السريع بنفس الوظائف.
- الرسمة هي العنصر البصري المميز؛ باقي السطح هادئ. روجع الاتجاه مقابل المرجع وأزيلت ألوان التوصيل البرتقالية والوظائف غير الموجودة. الحركة خفيفة وتُوقف عند طلب تقليل الحركة.

## الأصول

توليد صورتين أصليتين بأداة image_gen المدمجة، بخلفية شفافة، وحفظهما داخل المشروع:

- `assets/image/studentry_dental_companion.png`: طالبة طب أسنان بمعطف أبيض وملابس فيروزية، دفتر ومرآة أسنان، وسن وكتب وتقويم. مجسم ثلاثي الأبعاد لطيف بلا كتابة أو علامة مائية.
- `assets/image/studentry_splash_study.png`: سن أبيض فوق كتب فيروزية وبجانبه تقويم، بنفس الأسلوب، دون تغيير شعار التطبيق. يستخدم في السبلاش الأصلي.

البرومبتان النهائيان يحددان: matte 3D clay، turquoise #1195A7، pale cyan #E8F6F7، white، slate، transparent background، no lettering/no watermark. المشهد الأول يجمع الدراسة والممارسة والمواعيد، والثاني يبسط المحاور نفسها لتناسب شاشة بدء Android.

## ضوابط التنفيذ

العمل في مستودع Flutter فقط. لا تعديل للموقع أو APIs أو التخزين أو الصلاحيات. تأكيد إزالة المنتج لا يزيله قبل موافقة المستخدم، ويشمل زر الإزالة وخفض الكمية من واحد. الحقول الاختيارية تبقى اختيارية؛ لا إلغاء لمتطلبات الحساب أو بيانات ضرورية لتنفيذ عملية موجودة. تُضبط قيود الإدخال بحسب نوع القيمة، لا حد موحد يقطع البيانات أو كلمات المرور.

## نتائج التنفيذ والتحقق

- أعيد تصميم الرئيسية والدخول والترحيب وإنشاء الحساب ورمز التحقق واستعادة كلمة المرور، مع رسوم محلية تعمل دون اتصال. حركة الرسم داخل Flutter؛ سبلاش Android الأصلي ثابت ويظهر دون إضافة تأخير مصطنع لبدء التطبيق.
- بقي الفيروزي `#1195A7` والنص الأبيض للأزرار الأساسية، وضُبطت المحاذاة الرأسية والمساحة الداخلية في أنماط الأزرار وحقول الدخول.
- بقيت شروط الإلزام كما كانت. ضُبطت الأرقام العربية والفارسية، حقول الهاتف والمبالغ والأعمار والنصوص، وحدود الساعات الأكاديمية المطابقة للخادم. لا تحديد لطول كلمات المرور في منسّقات الإدخال. أُبقي إدخال الدرجات الجماعي بحد واسع مناسب للّصق.
- وقت المحاضرة اختياري ويستخدم منتقي بدء وانتهاء، مع الحفاظ على صيغة التخزين السابقة `HH:mm - HH:mm`. إلغاء المنتقي لا يعدّل القيمة. في تعديل المحاضرات الموجودة لا يظهر مسح غير فعال لأن مسار الحفظ القديم يحافظ على الوقت عند إرسال قيمة فارغة.
- تأكيد إزالة منتج السلة يشمل زر الإزالة وزر إنقاص كمية واحد؛ الإلغاء أو إغلاق الحوار يبقيان المنتج. إنقاص كمية أكبر من واحد يبقى مباشرًا.
- `flutter analyze --no-pub`: دون ملاحظات. `flutter test --no-pub --reporter expanded`: **234 ناجحًا وواحد متخطى**. تتضمن الاختبارات 46 حالة واجهات على عروض 320 و390 و720 مع تكبير خط حتى 150%، وظهور لوحة المفاتيح، وبقاء حقول التسجيل المطلوبة، وتقليل الحركة، ومنتقي الوقت، واختبارات فعلية لتأكيد إزالة السلة.
- بُني Android ARM64 موقّع للـAPI الحالي، بالنسخة `1.0.0-ui.20261029` ورقم البناء `20261029`. طُوبق توقيع APK مع التطبيق المثبّت قبل التحديث. نجح `adb install -r` وتحقق رقم البناء على الهاتف؛ لم يُحذف التطبيق أو تُمسح بياناته أو يُسجّل الخروج منه. نُسخ APK أيضًا إلى `Download/Studentry-20261029.apk` على الهاتف.
- النسخة المحلية: `build/releases/studentry-android-ui-20261029.apk`، SHA-256: `9B490CCA7D43B11540F25D25AEC3DF7312CE1C4D0A0C1D0A8A35BAD43EBF5593`.
- صور اختبارات الواجهات وسجلات الفحص في `build/mobile-ui-review-20261029/`. تستخدم صور الاختبار خطًا محليًا بديلًا، ولا تغيّر خط Cairo الفعلي للتطبيق. بعض الحروف اللاتينية في زر Google لا تُرسم في بيئة الاختبار؛ تحقق عرضها الصحيح على الموبايل الفعلي في `device-app.png`.
- اكتمل فحص الدخول والترحيب والسبلاش على Samsung SM-S938B بعد فتح القفل، وتحقق الخط العربي وGoogle ومحاذاة الأزرار وعدم قص الرسمة. لقطتا `device-app.png` و`device-after-restart.png` توثقان الواجهتين، و`device-splash.png` توثق السبلاش أثناء انتقال النظام. لم يظهر خطأ Flutter أو AndroidRuntime في سجل التطبيق المقروء بعد التشغيل. لم يُجرَ تسجيل دخول جديد أو إنشاء بيانات فعلية لهذا الفحص؛ الرئيسية وتأكيد السلة فُحصا باختبارات Widgets ببيانات معزولة.
- لإعادة توليد سبلاش Android فقط: `dart run tool/generate_mobile_splash.dart`. يحافظ السكربت على الهامش الآمن لدائرة Android 12. ملف iOS المعدل مسبقًا خارج هذا العمل ولم يُعد توليده.

## النصوص النهائية لتوليد الصور

الأداة: `image_gen.imagegen`، توليد جديد بخيار `transparent_background: true`، دون صور مرجعية. استُخدمت النواتج كما هي، والتحريك برمجي داخل التطبيق.

### رسمة طالب الأسنان

> Use case: stylized-concept. Asset type: production transparent cutout illustration for Studentry Android mobile app login header, home welcome, and onboarding. Create an original polished friendly 3D clay illustration: a young adult dental student in a white lab coat over turquoise scrubs (#1195A7), holding a mint notebook and a small dental mirror, seated beside an oversized smooth white molar model, with two compact study books and a small turquoise appointment calendar at the base. Rounded warm approachable face, natural anatomy, no delivery uniform, no parcel, no truck. This app unifies dental students' study materials, patient records and appointments and a dental supplies store. Palette: exact turquoise #1195A7 dominant accents, pale cyan #E8F6F7, white #FFFFFF, slate #1E293B, natural subtle skin/hair. Matte clay, soft studio lighting, restrained shadows. One cohesive compact scene, three-quarter view, full figure and props visible, centered with 8 percent clear padding all around. Objects must remain distinct and readable at 180 pixels tall. Truly transparent background. No lettering, no numbers, no logo, no watermark, no UI, no frame. Premium app mascot scene rather than medical photography.

المسار: `assets/image/studentry_dental_companion.png`.

### رسمة السبلاش

> Use case: stylized-concept. Asset type: original production splash illustration for Studentry dental student Android app; compact transparent center emblem, not an app logo redesign. A smooth friendly oversized white molar resting partly on two compact study notebooks with turquoise #1195A7 covers, with a small pale cyan #E8F6F7 appointment calendar tucked at its side. Elegant polished matte 3D clay style, soft studio lighting, readable silhouette, minimal props and restrained shadow, tasteful medical student identity. Compact balanced square composition with generous 18 percent transparent padding on every side so it fits inside Android 12 splash safe circle. White tooth, turquoise book spines, pale cyan calendar, slate small details. No character, no face on the tooth, no lettering, no numbers, no logo, no watermark, no frame, no UI. Truly transparent background.

المسار: `assets/image/studentry_splash_study.png`.
