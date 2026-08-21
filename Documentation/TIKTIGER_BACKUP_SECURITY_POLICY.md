# Tiktiger Backup Security Policy

## Scope

هذه الوثيقة تصف **configuration backup foundation** داخل System Center فقط. لا تقوم البنية الحالية بتصدير binaries أو Dylibs أو credentials أو Target App data، ولا تنفذ persistence أو file transport أو host integration.

## Accepted Backup Envelope

لا يُقبل payload للاستيراد إلا إذا حقق الشروط التالية:

| Field | Required value or rule |
|---|---|
| `backupSchemaVersion` | Numeric `1` |
| `format` | `tiktiger.configuration-backup` |
| `sourceFeatureID` | `system.center` |
| `managedFeatureIDs` | القائمة المعروفة الحالية وبالترتيب نفسه |
| `authenticity.policyVersion` | `1` |
| `authenticity.issuer` | `Tiktiger` |
| `authenticity.scope` | `configuration-only` |
| `authenticity.integrityAlgorithm` | `SHA-256` |
| `authenticity.signatureRequired` | `NO` for this local foundation only |
| `integrity.algorithm` | `SHA-256` |
| `integrity.digest` | SHA-256 للتسلسل canonical لـ `systemConfiguration` و`managedFeatureIDs` |

يُرفض payload عند غياب أي من هذه الحقول، أو عند اختلاف issuer/format/scope/policy، أو عند اختلاف managed feature allowlist، أو عند عدم تطابق digest، أو عند فشل system configuration validation.

## Authenticity and Integrity Semantics

يقدم envelope الحالي **structural authenticity** من خلال issuer وformat وscope وsource feature والسياسة الثابتة، ويقدم **tamper detection** من خلال SHA-256 digest محسوب على payload canonical باستخدام sorted JSON keys. هذا يمنع التعديل العرضي أو التغيير غير المتسق قبل الاستيراد.

> SHA-256 بدون secret key أو signature لا يثبت هوية مصدر خارجي موثوق. لذلك فإن `signatureRequired = NO` مقصودة في هذه foundation المحلية، ولا يجوز اعتبار payload موثقًا لمصدر خارجي أو قناة نقل غير موثوقة.

قبل أي استعمال external أو host-integrated يجب اعتماد امتداد مستقل يضيف signing key lifecycle أو authenticated encryption، مع key rotation وreplay policy وrestore tests. لا تدخل هذه الوثيقة credentials أو key material داخل Dylib.

## Safe Import and Reset

الاستيراد لا يغيّر configuration إلا بعد اكتمال جميع checks. عند الفشل يُعاد error redacted إلى caller ويُسجل system error bounded تحت lock. أما safe reset فيطبق fallback configuration الخاصة بـ System Center وحده، ولا يعيد ضبط حالة الوحدات الأخرى أو بيانات المضيف.

## Diagnostics Redaction

تُزال URLs وfilesystem paths ومحارف السطر من diagnostic strings قبل التخزين أو العرض. لا يجب تصدير `localizedDescription` خامًا إلى telemetry أو support upload. أي future export يجب أن يمر عبر نفس redaction boundary وأن يطبق policy الخاصة بالتشفير والتوقيع قبل مغادرة العملية.

## Operational Acceptance

| Control | Status |
|---|---|
| Schema and type validation | Implemented |
| Source and issuer checks | Implemented |
| Allowlist checks | Implemented |
| SHA-256 tamper detection | Implemented |
| Locked error recording | Implemented |
| Deep immutable export snapshot | Implemented |
| Encryption | Not implemented in configuration-only foundation |
| Cryptographic signature | Not implemented; required before external trust |
| File persistence | Not implemented by design |
| Target App integration | Not started |
