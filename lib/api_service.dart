const String baseUrl =
    'https://api.openrouteservice.org/v2/directions/driving-car';
const String apiKey =
    '5b3ce3597851110001cf62483f4bdc79d0cf43e094c6e1a669b2f9b8';
const firebase_server_key =
    'AAAAPncIkPU:APA91bELjYsziJXSg1Nxe45F66bhse9ebSTU1Aj-lPFN-B802svN_PuUZzNcKV4YAENzBqO28okVtHxBxT3xpHwLF-2LLJeI7c_cKExG_clYen16nQ3dQiolUrKjaqBPUQFTNeTxVq54';

getRouteUrl(String startPoint, String endPoint) {
  return Uri.parse('$baseUrl?api_key=$apiKey&start=$startPoint&end=$endPoint');
}
