package com.moonplex.app

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import dalvik.system.DexClassLoader
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val PLATFORM_CHANNEL = "com.moonplex.app/platform"
    private val CS3_CHANNEL = "com.moonplex.app/cs3"
    
    private val loadedProviders = mutableMapOf<String, Any?>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Platform detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PLATFORM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isTvDevice" -> {
                    val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    val isTv = uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
                    result.success(isTv)
                }
                else -> result.notImplemented()
            }
        }
        
        // CS3 provider loading channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CS3_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadProvider" -> {
                    val jarPath = call.argument<String>("jarPath")
                    val internalName = call.argument<String>("internalName")
                    if (jarPath != null && internalName != null) {
                        val success = loadProvider(jarPath, internalName)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGS", "jarPath and internalName required", null)
                    }
                }
                "callProvider" -> {
                    val internalName = call.argument<String>("internalName")
                    val method = call.argument<String>("method")
                    val args = call.argument<Map<String, Any>>("args")
                    if (internalName != null && method != null) {
                        val callResult = callProvider(internalName, method, args ?: emptyMap())
                        result.success(callResult)
                    } else {
                        result.error("INVALID_ARGS", "internalName and method required", null)
                    }
                }
                "unloadProvider" -> {
                    val internalName = call.argument<String>("internalName")
                    if (internalName != null) {
                        unloadProvider(internalName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "internalName required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun loadProvider(jarPath: String, internalName: String): Boolean {
        return try {
            val jarFile = File(jarPath)
            if (!jarFile.exists()) {
                return false
            }
            
            // Create optimized dex directory
            val dexDir = File(cacheDir, "dex_$internalName")
            if (!dexDir.exists()) {
                dexDir.mkdirs()
            }
            
            // Load the JAR using DexClassLoader
            val classLoader = DexClassLoader(
                jarPath,
                dexDir.absolutePath,
                null,
                classLoader.parent
            )
            
            // Try to find and instantiate the main provider class
            // CS3 providers typically have a class named after the provider
            val className = "com.lagradost.cloudstream3.$internalName.MainActivity"
                .replaceFirstChar { it.uppercase() }
            
            try {
                val providerClass = classLoader.loadClass(className)
                val instance = providerClass.newInstance()
                loadedProviders[internalName] = instance
                true
            } catch (e: ClassNotFoundException) {
                // Try alternative naming convention
                try {
                    val altClassName = internalName.replaceFirstChar { it.uppercase() } + "Provider"
                    val providerClass = classLoader.loadClass("com.lagradost.cloudstream3.$altClassName")
                    val instance = providerClass.newInstance()
                    loadedProviders[internalName] = instance
                    true
                } catch (e2: Exception) {
                    // Provider loaded but class instantiation failed - still consider it loaded
                    loadedProviders[internalName] = null
                    true
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    private fun callProvider(internalName: String, method: String, args: Map<String, Any>): Any? {
        val instance = loadedProviders[internalName] ?: return null
        return try {
            val methodObj = instance.javaClass.getMethod(method, Map::class.java)
            methodObj.invoke(instance, args)
        } catch (e: NoSuchMethodException) {
            null
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    private fun unloadProvider(internalName: String) {
        loadedProviders.remove(internalName)
        // Clean up dex cache
        val dexDir = File(cacheDir, "dex_$internalName")
        if (dexDir.exists()) {
            dexDir.deleteRecursively()
        }
    }
}
