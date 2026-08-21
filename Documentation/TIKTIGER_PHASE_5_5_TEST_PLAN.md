# TIKTIGER_PHASE_5_5_TEST_PLAN

## Scope

هذه خطة اختبار مصدرية وبنيوية لـ Phase 5.5. لا تنفذ Build فعليًا ولا Code Signing ولا IPA ولا Integration. الهدف هو تحديد حالات القبول قبل التحقق على macOS/Xcode.

## 1. Download Module Lifecycle

| Test ID | Scenario | Expected result |
|---|---|---|
| DM-01 | إنشاء `TiktigerDownloadModule` بإعدادات صالحة | يبدأ في `Idle` وتظهر queue فارغة وprogress يساوي صفرًا |
| DM-02 | `enable` مع queueLimit موجب | ينتقل Module إلى Enabled |
| DM-03 | `enable` مع queueLimit غير صالح | يفشل مع error منقح ولا يبدأ محرك تنزيل |
| DM-04 | enqueue Video/Audio/Image | يضاف العنصر وتصبح الحالة Preparing |
| DM-05 | enqueue بنوع غير مسموح | يرفض الإدخال ويصدر error |
| DM-06 | تجاوز queueLimit | يرفض الإدخال ويحافظ على العناصر السابقة |
| DM-07 | `prepareNext` مع queue غير فارغة | تصبح الحالة Loading ويظهر active item |
| DM-08 | `prepareNext` مع queue فارغة | تصبح الحالة Failed مع error قابل للتشخيص |
| DM-09 | `updateProgress` بين 0 و1 | يحدث progress والحالة Loading أو Processing |
| DM-10 | progress خارج النطاق | يرفض التحديث دون تغيير غير آمن |
| DM-11 | `completeCurrent` | تصبح الحالة Completed ويزال active item |
| DM-12 | `failCurrentWithError` | تصبح الحالة Failed ويُحفظ lastError وerror count |
| DM-13 | `downloadSnapshot` | يعيد state/version/progress/queue/lastError |

## 2. Preferences Module

| Test ID | Scenario | Expected result |
|---|---|---|
| PM-01 | إنشاء defaults صالحة | يحتوي config على schema/theme/animation/interface/features |
| PM-02 | theme = black أو system | validation passes |
| PM-03 | theme غير معروف | validation fails ويستخدم safe fallback |
| PM-04 | update animation settings | يحدث قسم animation فقط مع بقاء بقية config |
| PM-05 | update interface settings | يحدث قسم interface فقط |
| PM-06 | update feature preferences | يحدث قسم features فقط |
| PM-07 | migration من إصدار أقل | يحدث schemaVersion وmigrationVersion |
| PM-08 | downgrade migration | يرفض العملية ويعيد safe fallback |
| PM-09 | `preferencesSnapshot` | يعرض version/state/config/errorCount/migrationVersion |
| PM-10 | `healthCheck` بعد config صالح | healthy=true وconfigurationState=valid |
| PM-11 | `healthCheck` بعد config غير صالح | healthy=false أو fallback state مع error منقح |

## 3. UI Binding

| Test ID | Surface | Expected result |
|---|---|---|
| UB-01 | Dashboard + binding | تظهر Feature Status Card من `dashboardFeatureCards` |
| UB-02 | Settings + binding | تظهر Platform/Media/Theme/Animation/Interface/Features controls |
| UB-03 | Download Center + binding | يطبق state/progress/queue من `downloadPresentationState` |
| UB-04 | Diagnostics + binding | تظهر health rows لكل Module |
| UB-05 | binding absent | تبقى الشاشة قابلة للعرض دون crash أو direct Core access |
| UB-06 | degraded/failed state | تستخدم label وnext action ولا تعتمد على اللون فقط |

## 4. Diagnostics and Health

| Test ID | Scenario | Expected result |
|---|---|---|
| DH-01 | module health snapshot | كل Module يعيد featureID/name/version/state/healthy |
| DH-02 | Download failure | lastError وerrorCount يظهران في health snapshot |
| DH-03 | Preferences validation failure | configurationState يساوي fallback أو error واضح |
| DH-04 | Health Monitor aggregation | moduleCount وfailedModuleCount متسقان مع snapshot |
| DH-05 | Diagnostics Center presentation | Summary وRows قابلة للقراءة وredaction محفوظ |

## 5. Configuration Safety

يجب التحقق من أن كل Module يستخدم defaults، وأن validation يمنع الأنواع غير الصحيحة، وأن migration لا يسمح بالـ downgrade، وأن safe fallback يمنع تشغيل config غير موثوق. لا تُستخدم شبكة أو تخزين إنتاجي أو target-specific behavior في هذه المرحلة.

## 6. Static Safety Gates

قبل أي تحقق على macOS/Xcode، يجب أن تمر الملفات بفحص عدم وجود IPA أو compiled Dylib في مساحة المشروع، وعدم وجود imports إلى Core من UI، وعدم وجود Legacy hooks أو Substrate أو Theos أو Logos أو Target App integration، وثبات Core Foundation مقارنةً بأرشيف Phase 3.

## 7. Build Boundary

هذه الخطة لا تدعي أن الاختبارات نفذت. الذي يمكن فحصه في Linux هو وجود الملفات والعقود وتوازن Objective-C ومراجع Xcode والقيود النصية. يظل compile وruntime test على iOS Simulator أو device خطوة لاحقة خارج Phase 5.5 الحالية.

## References

[1]: TIKTIGER_FEATURE_MODULE_SYSTEM.md "Tiktiger Feature Module System"

[2]: TIKTIGER_FINAL_DESIGN_LOCK.md "Tiktiger Final Design Lock"
