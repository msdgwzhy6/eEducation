package io.agora.education.service;

import io.agora.education.service.bean.ResponseBody;
import io.agora.education.service.bean.request.RoomEntryReq;
import io.agora.education.service.bean.response.RoomEntryRes;
import retrofit2.Call;
import retrofit2.http.Body;
import retrofit2.http.Header;
import retrofit2.http.POST;
import retrofit2.http.Path;

public interface RoomService {

    @POST("edu/v2/apps/{appId}/room/entry")
    Call<ResponseBody<RoomEntryRes>> roomEntry(
            @Header("Authorization") String authorization,
            @Path("appId") String appId,
            @Body RoomEntryReq body
    );

}
