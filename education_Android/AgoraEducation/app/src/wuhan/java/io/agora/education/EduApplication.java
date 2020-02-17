package io.agora.education;

import android.app.Application;

import io.agora.base.LogManager;
import io.agora.base.PreferenceManager;
import io.agora.base.ToastManager;

public class EduApplication extends Application {

    @Override
    public void onCreate() {
        super.onCreate();

        PreferenceManager.init(this);
        ToastManager.init(this);
        LogManager.setTagPre("education_");
    }

}
