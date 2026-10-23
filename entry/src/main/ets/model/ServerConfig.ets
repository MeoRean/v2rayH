export class ServerConfig {
  name: string = '';
  protocol: string = '';
  address: string = '';
  port: number = 0;
  uuid: string = '';
  password: string = '';
  method: string = '';
  alterId: number = 0;
  scy: string = 'auto';
  flow: string = '';
  security: string = 'none';
  sni: string = '';
  fp: string = '';
  pbk: string = '';
  sid: string = '';
  spx: string = '/';
  allowInsecure: boolean = false;
  network: string = 'tcp';
  headerType: string = 'none';
  path: string = '';
  host: string = '';
}

// JSON-parsed nodes (subs.json / backups) are plain objects: fields added to
// the class after the file was saved come back as undefined, not as the class
// defaults. Rebuild every node through the constructor so all fields exist.
export function normalizeServer(raw: ServerConfig): ServerConfig {
  let s = new ServerConfig();
  s.name = raw.name !== undefined ? raw.name : '';
  s.protocol = raw.protocol !== undefined ? raw.protocol : '';
  s.address = raw.address !== undefined ? raw.address : '';
  s.port = raw.port !== undefined ? raw.port : 0;
  s.uuid = raw.uuid !== undefined ? raw.uuid : '';
  s.password = raw.password !== undefined ? raw.password : '';
  s.method = raw.method !== undefined ? raw.method : '';
  s.alterId = raw.alterId !== undefined ? raw.alterId : 0;
  s.scy = raw.scy !== undefined && raw.scy.length > 0 ? raw.scy : 'auto';
  s.flow = raw.flow !== undefined ? raw.flow : '';
  s.security = raw.security !== undefined ? raw.security : 'none';
  s.sni = raw.sni !== undefined ? raw.sni : '';
  s.fp = raw.fp !== undefined ? raw.fp : '';
  s.pbk = raw.pbk !== undefined ? raw.pbk : '';
  s.sid = raw.sid !== undefined ? raw.sid : '';
  s.spx = raw.spx !== undefined && raw.spx.length > 0 ? raw.spx : '/';
  s.allowInsecure = raw.allowInsecure === true;
  s.network = raw.network !== undefined ? raw.network : 'tcp';
  s.headerType = raw.headerType !== undefined ? raw.headerType : 'none';
  s.path = raw.path !== undefined ? raw.path : '';
  s.host = raw.host !== undefined ? raw.host : '';
  return s;
}
