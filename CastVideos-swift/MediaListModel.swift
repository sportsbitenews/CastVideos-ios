// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
import Foundation
import GoogleCast

/** A key for the URL of the media item's poster (large image). */
let kMediaKeyPosterURL: String = "posterUrl"
/** A key for the media item's extended description. */
let kMediaKeyDescription: String = "description"

let kKeyCategories: String = "categories"

let kKeyMP4BaseURL: String = "mp4"

let kKeyImagesBaseURL: String = "images"

let kKeyTracksBaseURL: String = "tracks"

let kKeySources: String = "sources"

let kKeyVideos: String = "videos"

let kKeyArtist: String = "artist"

let kKeyBaseURL: String = "baseUrl"

let kKeyContentID: String = "contentId"

let kKeyDescription: String = "description"

let kKeyID: String = "id"

let kKeyImageURL: String = "image-480x270"

let kKeyItems: String = "items"

let kKeyLanguage: String = "language"

let kKeyMimeType: String = "mime"

let kKeyName: String = "name"

let kKeyPosterURL: String = "image-780x1200"

let kKeyStreamType: String = "streamType"

let kKeyStudio: String = "studio"

let kKeySubtitle: String = "subtitle"

let kKeySubtype: String = "subtype"

let kKeyTitle: String = "title"

let kKeyTracks: String = "tracks"

let kKeyType: String = "type"

let kKeyURL: String = "url"

let kKeyDuration: String = "duration"

let kDefaultVideoMimeType: String = "video/mp4"

let kDefaultTrackMimeType: String = "text/vtt"

let kTypeAudio: String = "audio"

let kTypePhoto: String = "photos"

let kTypeVideo: String = "videos"

let kTypeLive: String = "live"

let kThumbnailWidth: Int = 480

let kThumbnailHeight: Int = 720

let kPosterWidth: Int = 780

let kPosterHeight: Int = 1200

/**
 * The delegate protocol for receiving notifications from the model.
 */
protocol MediaListModelDelegate: NSObjectProtocol {
  /**
   * Called when the media list has loaded.
   *
   * @param list The media list.
   */
  func mediaListModelDidLoad(_ list: MediaListModel)
  /**
   * Called when the media list has failed to load.
   *
   * @param list The media list.
   * @param error The error.
   */

  func mediaListModel(_ list: MediaListModel, didFailToLoadWithError error: Error?)
}

/**
 * An object representing a hierarchy of media items.
 */
class MediaListModel: NSObject, NSURLConnectionDelegate, NSURLConnectionDataDelegate {
  var request: URLRequest!
  var connection: NSURLConnection!
  var responseData: Data!
  var responseStatus: Int = 0
  var trackStyle: GCKMediaTextTrackStyle!
  /* The root item (top-level group). */
  private(set) public var rootItem: MediaItem!

  /** A delegate for receiving notifications from the model. */
  weak var delegate: MediaListModelDelegate?
  /** A flag indicating whether the model has been loaded. */
  private(set) public var isLoaded: Bool = false
  /** The title of the media list. */
  private(set) var title: String = ""

  /** Storage for the list of Media objects. */
  var medias = [Any]()

  /**
   * Begins loading the model from the given URL. The delegate will be messaged
   * when the load
   * completes or fails.
   *
   * @param url The URL of the JSON file describing the media hierarchy.
   */

  func load(from url: URL) {
    self.rootItem = nil
    self.request = URLRequest(url: url)
    self.connection = NSURLConnection(request: self.request, delegate: self)
    self.responseData = nil
    self.connection.start()
    GCKLogger.sharedInstance().delegate?.logMessage!("loading media list from URL \(url)", fromFunction: #function)
  }



  override init() {
    super.init()

    self.trackStyle = GCKMediaTextTrackStyle.createDefault()

  }

  func cancelLoad() {
    if self.request != nil {
      self.connection.cancel()
      self.request = nil
      self.connection = nil
      self.responseData = nil
    }
  }
  // MARK: - NSURLConnectionDelegate

  func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
    self.request = nil
    self.responseData = nil
    self.connection = nil
    GCKLogger.sharedInstance().delegate?.logMessage!("httpRequest failed with \(error)", fromFunction: #function)
    self.delegate?.mediaListModel(self, didFailToLoadWithError: error)
  }
  // MARK: - NSURLConnectionDataDelegate

  internal func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
    if let response = response as? HTTPURLResponse {
      self.responseStatus = response.statusCode
    }
  }

  func connection(_ connection: NSURLConnection, didReceive data: Data) {
    if !(self.responseData != nil) {
      self.responseData = Data()
    }
    self.responseData.append(data)
  }

  func connectionDidFinishLoading(_ connection: NSURLConnection) {
    GCKLogger.sharedInstance().delegate?.logMessage!("httpRequest completed with \(self.responseStatus)", fromFunction: #function)
    if self.responseStatus == 200 {
      let jsonData = (try? JSONSerialization.jsonObject(with: self.responseData, options: .mutableContainers))
      self.rootItem = self.decodeMediaTree(fromJSON: jsonData! as! NSDictionary)
      self.isLoaded = true
      self.delegate?.mediaListModelDidLoad(self)
    }
    else {
      let error = NSError.init(domain: "HTTP", code: self.responseStatus, userInfo: nil)
      self.delegate?.mediaListModel(self, didFailToLoadWithError: error)
    }
  }
  // MARK: - JSON decoding

  func decodeMediaTree(fromJSON json: NSDictionary) -> MediaItem {
    let rootItem = MediaItem(title: nil, imageURL: nil, parent: nil)
    let categories = json.gck_array(forKey: kKeyCategories)!
    for categoryElement in categories {
      if !(categoryElement is [AnyHashable: Any]) {
        continue
      }
      let category  = (categoryElement as? NSDictionary)
      let mediaList = category?.gck_array(forKey: kKeyVideos)
      if (mediaList != nil) {
        self.title = (category?.gck_string(forKey: kKeyName))!
        // Pick the MP4 files only
        let videosBaseURLString: String? = category?.gck_string(forKey: kKeyMP4BaseURL)
        let videosBaseURL = URL(string: videosBaseURLString!)
        let imagesBaseURLString: String? = category?.gck_string(forKey: kKeyImagesBaseURL)
        let imagesBaseURL = URL(string: imagesBaseURLString!)
        let tracksBaseURLString: String? = category?.gck_string(forKey: kKeyTracksBaseURL)
        let tracksBaseURL = URL(string: tracksBaseURLString!)
        self.decodeItemList(fromArray: mediaList!, into: rootItem, videoFormat: kKeyMP4BaseURL, videosBaseURL: videosBaseURL!, imagesBaseURL: imagesBaseURL!, tracksBaseURL: tracksBaseURL!)
        break
      }
    }
    return rootItem
  }

  func buildURL(with string: String?, baseURL: URL) -> URL? {
    guard let string = string else { return nil}
    if string.hasPrefix("http://") || string.hasPrefix("https://") {
      return URL(string: string)!
    }
    else {
      return URL(string: string, relativeTo: baseURL)!
    }
  }

  func decodeItemList(fromArray array: [Any], into item: MediaItem, videoFormat: String, videosBaseURL: URL, imagesBaseURL: URL, tracksBaseURL: URL) {
    for element in array {
      if let dict = element as? NSDictionary {
        let metadata = GCKMediaMetadata(metadataType: .movie)
        if let title = dict.gck_string(forKey: kKeyTitle) {
          metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        }
        var mimeType: String? = nil
        var url: URL? = nil
        let sources: [Any] = dict.gck_array(forKey: kKeySources) ?? []
        for sourceElement in sources {
          if let sourceDict = sourceElement as? NSDictionary {
            let type: String? = sourceDict.gck_string(forKey: kKeyType)
            if (type == videoFormat) {
              mimeType = sourceDict.gck_string(forKey: kKeyMimeType)
              let urlText: String? = sourceDict.gck_string(forKey: kKeyURL)
              url = self.buildURL(with: urlText, baseURL: videosBaseURL)
              break
            }
          }
        }
        let imageURLString: String? = dict.gck_string(forKey: kKeyImageURL)
        let imageURL = self.buildURL(with: imageURLString, baseURL: imagesBaseURL)
        if let imageURL = imageURL {
          metadata.addImage(GCKImage(url: imageURL, width: kThumbnailWidth, height: kThumbnailHeight))
        }
        let posterURLText: String? = dict.gck_string(forKey: kKeyPosterURL)
        let posterURL = self.buildURL(with: posterURLText, baseURL: imagesBaseURL)
        if let posterURL = posterURL {
          metadata.setString(posterURL.absoluteString, forKey: kMediaKeyPosterURL)
          metadata.addImage(GCKImage(url: posterURL, width: kPosterWidth, height: kPosterHeight))
        }
        if let description = dict.gck_string(forKey: kKeySubtitle) {
          metadata.setString(description, forKey: kMediaKeyDescription)
        }
        var mediaTracks: [Any]? = nil
        if let studio = dict.gck_string(forKey: kKeyStudio) {
          metadata.setString(studio, forKey: kGCKMetadataKeyStudio)
        }
        let duration: Int? = dict.gck_integer(forKey: kKeyDuration)
        mediaTracks = [GCKMediaTrack]()
        if let tracks = dict.gck_array(forKey: kKeyTracks) {
          for trackElement: Any in tracks {
            guard let trackDict = trackElement as? NSDictionary else { continue }
            let identifier = trackDict.gck_integer(forKey: kKeyID)
            let name: String? = trackDict.gck_string(forKey: kKeyName)
            let typeString: String? = trackDict.gck_string(forKey: kKeyType)
            let subtypeString: String? = trackDict.gck_string(forKey: kKeySubtype)
            let contentID: String? = trackDict.gck_string(forKey: kKeyContentID)
            let language: String? = trackDict.gck_string(forKey: kKeyLanguage)
            let url = self.buildURL(with: contentID, baseURL: tracksBaseURL)
            let mediaTrack = GCKMediaTrack(identifier: identifier, contentIdentifier: url?.absoluteString, contentType: kDefaultTrackMimeType, type: self.trackType(from: typeString!), textSubtype: self.textTrackSubtype(from: subtypeString!), name: name, languageCode: language, customData: nil)
              mediaTracks?.append(mediaTrack)
          }
        }

        if mediaTracks?.count == 0 {
          mediaTracks = nil
        }
        let mediaInfo = GCKMediaInformation(contentID: url!.absoluteString, streamType: .buffered, contentType: mimeType!, metadata: metadata, streamDuration: TimeInterval(duration!), mediaTracks: mediaTracks as! [GCKMediaTrack]?, textTrackStyle: self.trackStyle, customData: nil)
        let childItem = MediaItem(mediaInformation: mediaInfo, parent: item)
          item.items.append(childItem)

      }
    }
  }

  func trackType(from string: String) -> GCKMediaTrackType {
    if (string == "audio") {
      return .audio
    }
    if (string == "text") {
      return .text
    }
    if (string == "video") {
      return .video
    }
    return .unknown
  }

  func textTrackSubtype(from string: String) -> GCKMediaTextTrackSubtype {
    if (string == "captions") {
      return .captions
    }
    if (string == "chapters") {
      return .chapters
    }
    if (string == "descriptions") {
      return .descriptions
    }
    if (string == "metadata") {
      return .metadata
    }
    if (string == "subtitles") {
      return .subtitles
    }
    return .unknown
  }
}