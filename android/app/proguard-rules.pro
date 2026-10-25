# flutter_local_notifications serialises scheduled notifications with Gson;
# keep its model classes and generic signatures so reminders survive R8.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
