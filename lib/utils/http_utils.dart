import 'dart:convert';
import 'package:collection/collection.dart' show mergeMaps;
import 'package:http_parser/http_parser.dart';
import 'package:xml/xml.dart';
import 'package:apidash/models/models.dart' show KVRow;
import 'convert_utils.dart' show rowsToMap;
import '../consts.dart';

String getRequestTitleFromUrl(String? url) {
  if (url == null || url.trim() == "") {
    return "untitled";
  }
  if (url.contains("://")) {
    String rem = url.split("://")[1];
    if (rem.trim() == "") {
      return "untitled";
    }
    return rem;
  }
  return url;
}

(String?, bool) getUriScheme(Uri uri) {
  if(uri.hasScheme){
    if(kSupportedUriSchemes.contains(uri.scheme)){
      return (uri.scheme, true);
    }
    return (uri.scheme, false);
  }
  return (null, false);
}

(Uri?, String?) getValidRequestUri(String? url, List<KVRow>? requestParams) {
  url = url?.trim();
  if(url == null || url == ""){
    return (null, "URL is missing!");
  }
  Uri? uri =  Uri.tryParse(url);
  if(uri == null){
    return (null, "Check URL (malformed)");
  }
  (String?, bool) urlScheme = getUriScheme(uri);

  if(urlScheme.$0 != null){
    if (!urlScheme.$1){
      return (null, "Unsupported URL Scheme (${urlScheme.$0})");
    }
  }
  else {
    url = kDefaultUriScheme + url;
  }

  uri =  Uri.parse(url);
  if (uri.hasFragment){
    uri = uri.removeFragment();
  }

  Map<String, String>? queryParams = rowsToMap(requestParams);
  if(queryParams != null){
    if(uri.hasQuery){
      Map<String, String> urlQueryParams = uri.queryParameters;
      queryParams = mergeMaps(urlQueryParams, queryParams);
    }
    uri = uri.replace(queryParameters: queryParams);
  }
  return (uri, null);
}

(List<ResponseBodyView>, String?)  getResponseBodyViewOptions(MediaType mediaType){
  var type = mediaType.type;
  var subtype = mediaType.subtype;
  //print(mediaType);
  if(kResponseBodyViewOptions.containsKey(type)){
    if(subtype.contains(kSubTypeJson)){
      subtype = kSubTypeJson;
    }
    if(subtype.contains(kSubTypeXml)){
      subtype = kSubTypeXml;
    }
    if (kResponseBodyViewOptions[type]!.containsKey(subtype)){
       return (kResponseBodyViewOptions[type]![subtype]!, kCodeHighlighterMap[subtype] ?? subtype);
    }
    return (kResponseBodyViewOptions[type]![kSubTypeDefaultViewOptions]!, subtype);
  }
  else {
    return (kNoBodyViewOptions, null);
  }
}

String? formatBody(String? body, MediaType? mediaType){
  if(mediaType != null && body != null){
    var subtype = mediaType.subtype;
    try {
      if(subtype.contains(kSubTypeJson)){        
        final tmp = jsonDecode(body);
        String result = kEncoder.convert(tmp);
        return result;
      }
      if(subtype.contains(kSubTypeXml)){
        final document = XmlDocument.parse(body);
        String result = document.toXmlString(pretty: true, indent: '  ');
        return result;
      }
      if(subtype == kSubTypeHtml){
        var len = body.length;
        var lines = kSplitter.convert(body);
        var numOfLines = lines.length;
        if(numOfLines !=0 && len/numOfLines <= kCodeCharsPerLineLimit){
          return body;
        }
      }
    } catch (e) {
      return null;
    }
  }
  return null;
}