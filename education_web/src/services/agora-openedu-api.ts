import { AgoraFetch } from "../utils/fetch";

const AUTHORIZATION_KEY: string = process.env.REACT_APP_AGORA_OPEN_EDU_AUTH_KEY as string;

const PREFIX = process.env.ENV === 'production' ? process.env.REACT_APP_AGORA_OPEN_EDU_API as string : '';

const APP_ID = process.env.REACT_APP_AGORA_APP_ID as string;

interface AgoraFetchJsonInit {
  url: string
  method: string
  data?: any
  token?: string
  authToken?: string
}

const AgoraFetchJson = async ({
  url,
  method,
  data,
  token,
  authToken
}: AgoraFetchJsonInit) => {
  const opts: any = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Basic ${authToken}`,
    }
  }

  if (data) {
    opts.body = JSON.stringify(data);
  }

  if (token) {
    opts.token = token;
  }

  let resp = await AgoraFetch(`${PREFIX}${url}`, opts);
  return resp.json();
}

export interface EntryRoomParams {
  roomId: string
  userName: string
  password: string
  role: number
  uuid: string
}

export class AgoraOpenEduApi {

  appID: string = APP_ID;
  authorization: string = AUTHORIZATION_KEY;

  // async config() {
  //   let json = await AgoraFetchJson({
  //     url: `${OPEN_EDU_API}/edu/v1/config`,
  //     method: 'GET',
  //   });
  //   if (json.code !== 0) throw json.msg;
  //   // this.appID = json.data.appId;
  //   // this.authorization = json.data.authorization;
  //   return {
  //     appId: json.data.appId,
  //     room: json.data.room,
  //   }
  // }

  async roomInfo(roomId: string) {
    let json = await AgoraFetchJson({
      url: `/edu/v2/apps/${this.appID}/room/${roomId}`,
      method: 'GET',
      authToken: this.authorization,
    });
    return {
      code: json.code,
      msg: json.msg,
      data: json.data
    }
  }

  /**
   * entry
   * @param params {@link EntryRoomParams}
   */
  async entry(params: EntryRoomParams) {
    let json = await AgoraFetchJson({
      url: `/edu/v2/apps/${this.appID}/room/entry`,
      method: 'POST',
      data: params,
      authToken: this.authorization,
    });
    return {
      code: json.code,
      msg: json.msg,
      data: json.data,
    }
  }

}

export const agoraOpenEduApi = new AgoraOpenEduApi();