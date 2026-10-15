import 'package:multicast_dns/multicast_dns.dart';

class MdnsDiscovery {
  static Future<String?> discoverDevice({Duration timeout = const Duration(seconds: 4)}) async {
    const String serviceType = '_smartgas._tcp.local';
    final MDnsClient client = MDnsClient();

    try {
      await client.start();
      await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(serviceType),
      ).timeout(timeout, onTimeout: (sink) => sink.close())) {
        await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(
          ResourceRecordQuery.service(ptr.domainName),
        )) {
          await for (final IPAddressResourceRecord ip in client.lookup<IPAddressResourceRecord>(
            ResourceRecordQuery.addressIPv4(srv.target),
          )) {
            client.stop();
            return ip.address.address;
          }
        }
      }
    } catch (e) {
      // mDNS error or timeout
    } finally {
      client.stop();
    }
    return null;
  }
}
