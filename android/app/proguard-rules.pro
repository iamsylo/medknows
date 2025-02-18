# TensorFlow Lite rules
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep class org.tensorflow.lite.nnapi.** { *; }
-keepclassmembers class org.tensorflow.lite.gpu.GpuDelegate { *; }
-keepclassmembers class org.tensorflow.lite.gpu.GpuDelegate$Options { *; }
-keepclassmembers class org.tensorflow.lite.gpu.GpuDelegateFactory { *; }
-keepclassmembers class org.tensorflow.lite.gpu.GpuDelegateFactory$Options { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
