import chronicles
import ../eventemitter
import statusgo_backend/settings
import statusgo_backend/core
import json
import uuids, strutils
import json_serialization
import ./types/[setting, fleet]

logScope:
  topics = "network-model"

type
  NetworkModel* = ref object
    peers*: seq[string]
    events*: EventEmitter
    connected*: bool

proc newNetworkModel*(events: EventEmitter): NetworkModel =
  result = NetworkModel()
  result.events = events
  result.peers = @[]
  result.connected = false

proc fetchPeers*(self: NetworkModel): seq[string] =
  var fleetStr = getSetting[string](Setting.Fleet)
  if fleetStr == "": fleetStr = "eth.prod"
  let fleet = parseEnum[Fleet](fleetStr)
  let isWakuV2 = if fleet == WakuV2Prod or fleet == WakuV2Test: true else: false
  if isWakuV2:
    return wakuV2Peers()
  else:
   return adminPeers()

proc peerSummaryChange*(self: NetworkModel, peers: seq[string]) =
  if peers.len == 0 and self.connected:
    self.connected = false
    self.events.emit("network:disconnected", Args())
  
  if peers.len > 0 and not self.connected:
      self.connected = true
      self.events.emit("network:connected", Args())

  self.peers = peers

proc peerCount*(self: NetworkModel): int = self.peers.len

proc isConnected*(self: NetworkModel): bool = self.connected

proc addNetwork*(self: NetworkModel, name: string, endpoint: string, networkId: int, networkType: string) =
  var networks = getSetting[JsonNode](Setting.Networks_Networks)
  let id = genUUID()
  networks.elems.add(%*{
    "id": $genUUID(),
    "name": name,
    "config": {
      "NetworkId": networkId,
      "DataDir": "/ethereum/" & networkType,
      "UpstreamConfig": {
        "Enabled": true,
        "URL": endpoint
      }
    }
  })
  discard saveSetting(Setting.Networks_Networks, networks)
