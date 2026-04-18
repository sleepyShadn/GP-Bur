Place these sound files in this folder (WAV or MP3; the code uses the exact names below).

Apple game:
- bg_game_loop.mp3
- game_start.wav
- apple_catch.wav
- apple_rotten.wav
- bonus_pickup.wav
- level_up.wav
- pause.wav
- resume.wav
- game_over.wav
- button_tap.wav

Garden / watering game (رعاية الحديقة) — أضف هذه الملفات بنفس الأسماء:
- garden_round_start.wav — (1) حلقة أثناء بطاقة «START GAME» حتى الضغط على START (2) نقرة قصيرة عند بداية كل جولة داخل اللعب بعد ذلك
- garden_tool_grab.wav — في لعبة الري: حلقة الخلفية بعد START؛ في لعبة الحصاد: قطفة صحيحة (SFX)
- bg_game_loop.mp3 — احتياطي لخلفية الري إذا فشل تحميل garden_tool_grab
- garden_care_bgm.mp3 — احتياطي ثانٍ لخلفية الري
- garden_water_spray.wav   — رش ماء قصير (يُكرَّر أثناء الري على نبتة حية)
- garden_fertilizer_pour.wav — سماد / حبيبات (يُكرَّر أثناء الإسقاء)
- garden_weed_waste.wav    — خطأ: ري أو سماد على عشب ضار
- garden_level_complete.wav — فوز بالجولة
- garden_game_over.wav     — خسارة أو انتهاء الوقت
- garden_timer_warning.wav — عندما يصبح الوقت ≤ 10 ثوانٍ
- garden_bonus_spawn.wav   — ظهور قطرة ماء إضافية (بونص الخزان)
- garden_bonus_pickup.wav  — لمس اللاعب للبونص وامتلاء الخزان
- garden_plant_focus_open.wav — فتح نبتة من الحقل للعرض القريب
- (يُستعاد من لعبة التفاحات) button_tap.wav — زر الخروج قبل نافذة التأكيد
- (يُستعاد من لعبة التفاحات) level_up.wav — الانتقال لجولة أعلى داخل جلسة الريّ

Harvest Run (حصاد الطلبات / السلّة) — تستخدم نفس مؤثرات الحديقة ولعبة التفاح أعلاه:
- garden_tool_grab.wav — قطفة صحيحة
- garden_weed_waste.wav — محصول خاطئ
- garden_round_start.wav, garden_level_complete.wav, garden_game_over.wav, garden_timer_warning.wav
- pause.wav, resume.wav, button_tap.wav, level_up.wav

ملاحظات:
- الصيغة المفضّلة: WAV غير مضغوط أو MP3 بمعدل عيّنة 44.1 kHz، مدة كل مؤثر 0.3–2 ثانية عادةً كافية.
- إن كان الملف ناقصاً، التطبيق يتجاهل الخطأ ولن يتوقف (try/catch داخل خدمة الصوت).
