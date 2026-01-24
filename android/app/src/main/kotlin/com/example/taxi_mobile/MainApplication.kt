package com.example.taxi_mobile

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication: Application() {
    override fun onCreate() {
        super.onCreate()
        MapKitFactory.setLocale("uz_UZ")
        // SDK key for MapKit (map display)
        MapKitFactory.setApiKey("438c7e3f-d370-4870-aa1c-9f366ad7bc3c")
        MapKitFactory.initialize(this)
    }
}
