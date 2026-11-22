package com.manatwal.vega

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.wifi.WifiManager
import android.net.wifi.WpsInfo
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.net.Inet4Address
import java.net.NetworkInterface

/**
 * Native Kotlin bridge providing:
 * 1. Wi-Fi Direct (WifiP2pManager) peer discovery, group creation, and GO IP resolution.
 * 2. LocalOnlyHotspot (5 GHz when hardware supports) for router-less Android <-> Android & Browser transfers.
 * 3. Play-Store-safe MediaStore export into Downloads/Vega (Android 10+ Scoped Storage).
 */
class WifiDirectBridge(private val context: Context) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val manager: WifiP2pManager? =
        context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
    private var channel: WifiP2pManager.Channel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private val intentFilter = IntentFilter().apply {
        addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
    }

    private val p2pReceiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                    val state = intent.getIntExtra(
                        WifiP2pManager.EXTRA_WIFI_STATE,
                        WifiP2pManager.WIFI_P2P_STATE_DISABLED
                    )
                    emitEvent(
                        mapOf(
                            "type" to "p2p_state",
                            "enabled" to (state == WifiP2pManager.WIFI_P2P_STATE_ENABLED)
                        )
                    )
                }

                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    val ch = channel ?: return
                    manager?.requestPeers(ch) { peersList ->
                        val mapped = peersList.deviceList.map { device ->
                            mapOf(
                                "name" to device.deviceName,
                                "address" to device.deviceAddress,
                                "status" to statusLabel(device.status)
                            )
                        }
                        emitEvent(mapOf("type" to "peers", "peers" to mapped))
                    }
                }

                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    val ch = channel ?: return
                    manager?.requestConnectionInfo(ch) { info: WifiP2pInfo? ->
                        if (info != null && info.groupFormed) {
                            emitEvent(
                                mapOf(
                                    "type" to "connected",
                                    "isGroupOwner" to info.isGroupOwner,
                                    "groupOwnerAddress" to (info.groupOwnerAddress?.hostAddress ?: "")
                                )
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        ensureInitialized()
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun ensureInitialized() {
        if (channel == null && manager != null) {
            channel = manager.initialize(context, Looper.getMainLooper(), null)
        }
        if (!receiverRegistered) {
            context.registerReceiver(p2pReceiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }
    }

    fun dispose() {
        if (receiverRegistered) {
            try {
                context.unregisterReceiver(p2pReceiver)
            } catch (_: Throwable) {
            }
            receiverRegistered = false
        }
        hotspotReservation?.close()
        hotspotReservation = null
    }

    @SuppressLint("MissingPermission")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        ensureInitialized()
        when (call.method) {
            "discoverPeers" -> {
                val ch = channel
                if (manager == null || ch == null) {
                    result.error("NO_P2P", "Wi-Fi Direct not supported on this device", null)
                    return
                }
                manager.discoverPeers(ch, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() = result.success(true)
                    override fun onFailure(reason: Int) =
                        result.error("DISCOVER_FAILED", "discoverPeers failed: code=$reason", null)
                })
            }

            "stopDiscovery" -> {
                val ch = channel
                if (manager != null && ch != null) {
                    manager.stopPeerDiscovery(ch, null)
                }
                result.success(true)
            }

            "connectPeer" -> {
                val address = call.argument<String>("address")
                val ch = channel
                if (manager == null || ch == null || address.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Missing peer MAC address", null)
                    return
                }
                val config = WifiP2pConfig().apply {
                    deviceAddress = address
                    wps.setup = WpsInfo.PBC
                    groupOwnerIntent = 0 // Prefer peer as Group Owner when sending
                }
                manager.connect(ch, config, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() = result.success(true)
                    override fun onFailure(reason: Int) =
                        result.error("CONNECT_FAILED", "Wi-Fi Direct connect failed: code=$reason", null)
                })
            }

            "createGroup" -> {
                val ch = channel
                if (manager == null || ch == null) {
                    result.error("NO_P2P", "Wi-Fi Direct not supported", null)
                    return
                }
                manager.createGroup(ch, object : WifiP2pManager.ActionListener {
                    override fun onSuccess() = result.success(true)
                    override fun onFailure(reason: Int) =
                        result.error("GROUP_FAILED", "createGroup failed: code=$reason", null)
                })
            }

            "removeGroup" -> {
                val ch = channel
                if (manager != null && ch != null) {
                    manager.removeGroup(ch, object : WifiP2pManager.ActionListener {
                        override fun onSuccess() = result.success(true)
                        override fun onFailure(reason: Int) = result.success(false)
                    })
                } else {
                    result.success(true)
                }
            }

            "startLocalHotspot" -> startLocalOnlyHotspot(result)

            "stopLocalHotspot" -> {
                hotspotReservation?.close()
                hotspotReservation = null
                result.success(true)
            }

            "getLocalIps" -> result.success(listLocalIpv4Addresses())

            "saveToDownloads" -> {
                val sourcePath = call.argument<String>("sourcePath")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (sourcePath.isNullOrBlank() || fileName.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "sourcePath and fileName are required", null)
                    return
                }
                try {
                    val savedLocation = exportFileToDownloads(sourcePath, fileName, mimeType)
                    result.success(savedLocation)
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startLocalOnlyHotspot(result: MethodChannel.Result) {
        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifiManager == null) {
            result.error("NO_WIFI", "WifiManager unavailable", null)
            return
        }
        hotspotReservation?.close()
        hotspotReservation = null

        wifiManager.startLocalOnlyHotspot(
            object : WifiManager.LocalOnlyHotspotCallback() {
                override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
                    hotspotReservation = reservation
                    val ssid = reservation.softApConfiguration.ssid ?: "Vega-AP"
                    val password = reservation.softApConfiguration.passphrase ?: ""
                    result.success(
                        mapOf(
                            "ssid" to ssid,
                            "password" to password,
                            "ips" to listLocalIpv4Addresses()
                        )
                    )
                }

                override fun onStopped() {
                    emitEvent(mapOf("type" to "hotspot_stopped"))
                }

                override fun onFailed(reason: Int) {
                    result.error("HOTSPOT_FAILED", "LocalOnlyHotspot failed: code=$reason", null)
                }
            },
            mainHandler
        )
    }

    private fun exportFileToDownloads(
        sourcePath: String,
        fileName: String,
        mimeType: String
    ): String {
        val sourceFile = File(sourcePath)
        require(sourceFile.exists()) { "Source file does not exist: $sourcePath" }

        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOWNLOADS}/Vega"
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Failed to create MediaStore Downloads entry")

        resolver.openOutputStream(uri)?.use { out ->
            FileInputStream(sourceFile).use { input ->
                val buffer = ByteArray(1024 * 512)
                var read: Int
                while (input.read(buffer).also { read = it } != -1) {
                    out.write(buffer, 0, read)
                }
                out.flush()
            }
        } ?: throw IllegalStateException("Cannot open MediaStore output stream")

        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        sourceFile.delete()
        return "Downloads/Vega/$fileName"
    }

    private fun listLocalIpv4Addresses(): List<String> {
        val ips = mutableListOf<String>()
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            for (iface in interfaces) {
                if (!iface.isUp || iface.isLoopback) continue
                for (addr in iface.inetAddresses) {
                    if (addr is Inet4Address && !addr.isLoopbackAddress) {
                        val host = addr.hostAddress ?: continue
                        if (!host.startsWith("169.254.")) {
                            ips.add(host)
                        }
                    }
                }
            }
        } catch (_: Throwable) {
        }
        return ips
    }

    private fun emitEvent(payload: Map<String, Any>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun statusLabel(status: Int): String = when (status) {
        WifiP2pDevice.AVAILABLE -> "available"
        WifiP2pDevice.INVITED -> "invited"
        WifiP2pDevice.CONNECTED -> "connected"
        WifiP2pDevice.FAILED -> "failed"
        WifiP2pDevice.UNAVAILABLE -> "unavailable"
        else -> "unknown"
    }
}
