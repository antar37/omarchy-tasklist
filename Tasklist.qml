import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons

// Tasklist: open windows grouped into one pill per Hyprland workspace.
//   left click   = focus window
//   middle click = close window
//   right drag   = move window to another workspace pill (or the "+N" pill for
//                  the first empty workspace). Left-drag is reserved by the
//                  Omarchy bar for rearranging widgets, so it can't be used here.
//
// Data comes live from Quickshell's Hyprland integration (Hyprland.toplevels):
// each entry knows its workspace, address and Wayland handle, so there is no
// polling and no class/title matching that breaks on changing window titles.
Item {
  id: root
  property var bar
  property string moduleName
  property var settings

  readonly property bool vertical: bar ? bar.vertical : false
  // Size everything off the bar thickness so pills are never clipped.
  readonly property int barThickness: bar && bar.barSize > 0 ? bar.barSize : 26
  readonly property int boxPad: 2
  readonly property int cell: barThickness - boxPad * 2 - 2
  readonly property int iconSize: Math.max(14, cell - 6)
  readonly property int boxGap: 6
  readonly property color fg: bar ? bar.barForeground : "white"

  property bool dragging: false

  function workspaceLabel(ws) {
    if (!ws) return "?"
    var name = String(ws.name || "")
    if (ws.id < 0) return name.indexOf("special:") === 0 ? "★" : (name || "★")
    return name || String(ws.id)
  }

  function groupedByWorkspace() {
    var order = []
    var buckets = {}
    var items = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < items.length; i++) {
      var hy = items[i]
      if (!hy || !hy.wayland) continue
      var ws = hy.workspace
      var key = ws ? String(ws.id) : "?"
      if (!buckets[key]) {
        buckets[key] = { key: key, label: root.workspaceLabel(ws), wsId: ws ? ws.id : null, items: [] }
        order.push(key)
      }
      buckets[key].items.push(hy)
    }
    order.sort(function(a, b) {
      var na = parseInt(a, 10), nb = parseInt(b, 10)
      if (isNaN(na) || isNaN(nb)) return isNaN(na) ? 1 : -1
      // Special (negative) workspaces go last.
      if ((na < 0) !== (nb < 0)) return na < 0 ? 1 : -1
      return na - nb
    })
    var out = []
    for (var j = 0; j < order.length; j++) out.push(buckets[order[j]])
    return out
  }

  // Live grouping, frozen while a drag is in progress so the dragged
  // delegate isn't destroyed by a regroup under the pointer.
  readonly property var liveGroups: root.groupedByWorkspace()
  property var groups: []
  onLiveGroupsChanged: if (!dragging) groups = liveGroups
  onDraggingChanged: if (!dragging) groups = liveGroups
  Component.onCompleted: groups = liveGroups

  readonly property int firstEmptyWorkspace: {
    var used = {}
    var g = root.liveGroups
    for (var i = 0; i < g.length; i++) if (g[i].wsId !== null) used[g[i].wsId] = true
    for (var n = 1; n <= 10; n++) if (!used[n]) return n
    return 10
  }

  function moveWindow(address, wsId) {
    var addr = String(address || "")
    if (addr.length && addr.indexOf("0x") !== 0) addr = "0x" + addr
    var ws = String(wsId === null || wsId === undefined ? "" : wsId)
    if (!/^0x[0-9a-fA-F]+$/.test(addr) || !/^-?[0-9]+$/.test(ws)) return
    var lua = 'hl.dsp.window.move({ workspace = "' + ws + '", follow = false, window = "address:' + addr + '" })'
    if (root.bar) root.bar.run("hyprctl dispatch '" + lua + "'")
  }

  implicitWidth: vertical ? (bar ? bar.barSize : 28) : Math.max(cell, outer.implicitWidth)
  implicitHeight: vertical ? Math.max(cell, outer.implicitHeight) : (bar ? bar.barSize : 26)

  function iconFor(appId) {
    var id = String(appId || "")
    if (id.length === 0) return Quickshell.iconPath("application-x-executable", true)
    var themed = Quickshell.iconPath(id, true)
    if (themed.length > 0) return themed
    var lower = id.toLowerCase()
    var apps = DesktopEntries.applications.values || []
    for (var i = 0; i < apps.length; i++) {
      var e = apps[i]
      var eid = String(e.id || "").toLowerCase()
      if (eid === lower || eid.indexOf(lower) !== -1 || lower.indexOf(eid) !== -1) {
        var ic = Quickshell.iconPath(e.icon, true)
        if (ic.length > 0) return ic
      }
    }
    return Quickshell.iconPath("application-x-executable", true)
  }

  Grid {
    id: outer
    anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
    anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
    columns: root.vertical ? 1 : root.groups.length + 1
    rowSpacing: root.boxGap
    columnSpacing: root.boxGap

    Repeater {
      model: root.groups

      Rectangle {
        id: groupBox
        required property var modelData
        property var grp: modelData
        readonly property bool dropHover: dropArea.containsDrag
        color: dropHover ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
        border.color: Commons.Color.accent
        border.width: dropHover ? 1 : 0
        radius: height / 2
        width: boxContent.implicitWidth + (root.vertical ? root.boxPad * 2 : 12)
        height: boxContent.implicitHeight + (root.vertical ? 10 : root.boxPad * 2)

        DropArea {
          id: dropArea
          anchors.fill: parent
          keys: ["tasklist-window"]
          onDropped: function(drop) {
            var src = drop.source
            if (!src || !groupBox.grp || groupBox.grp.wsId === null) return
            if (src.fromWs === groupBox.grp.wsId) return
            root.moveWindow(src.address, groupBox.grp.wsId)
          }
        }

        Grid {
          id: boxContent
          anchors.centerIn: parent
          columns: root.vertical ? 1 : 2
          rowSpacing: 2
          columnSpacing: 4
          verticalItemAlignment: Grid.AlignVCenter
          horizontalItemAlignment: Grid.AlignHCenter

          Text {
            text: groupBox.grp ? groupBox.grp.label : ""
            font.pixelSize: root.vertical ? 9 : 10
            opacity: 0.55
            color: root.fg
          }

          Grid {
            columns: root.vertical ? 1 : Math.max(1, groupBox.grp ? groupBox.grp.items.length : 1)
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
              model: groupBox.grp ? groupBox.grp.items : []

              Item {
                id: iconCell
                required property var modelData
                property var hy: modelData
                readonly property var win: hy ? hy.wayland : null
                readonly property bool tooltipHovered: visible && opacity > 0 && mouse.containsMouse && !mouse.drag.active
                width: root.cell
                height: root.cell

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: iconCell.win && iconCell.win.activated ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                  opacity: mouse.drag.active ? 0.35 : 1
                }

                // The piece that actually moves while dragging.
                Item {
                  id: dragItem
                  width: root.cell
                  height: root.cell
                  property string address: iconCell.hy ? String(iconCell.hy.address || "") : ""
                  property var fromWs: iconCell.hy && iconCell.hy.workspace ? iconCell.hy.workspace.id : null

                  Drag.active: mouse.drag.active
                  Drag.keys: ["tasklist-window"]
                  Drag.hotSpot.x: width / 2
                  Drag.hotSpot.y: height / 2

                  states: State {
                    when: mouse.drag.active
                    ParentChange { target: dragItem; parent: root }
                    PropertyChanges { target: dragItem; z: 1000 }
                  }

                  Image {
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    source: iconCell.win ? root.iconFor(iconCell.win.appId) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                  }
                }

                MouseArea {
                  id: mouse
                  anchors.fill: parent
                  acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                  hoverEnabled: true
                  cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                  drag.target: dragItem
                  drag.axis: root.vertical ? Drag.YAxis : Drag.XAxis
                  drag.threshold: 6

                  onPressed: function(m) {
                    // Only the right button may start a drag.
                    mouse.drag.target = (m.button === Qt.RightButton) ? dragItem : null
                  }
                  drag.onActiveChanged: {
                    root.dragging = mouse.drag.active
                    if (mouse.drag.active && root.bar) root.bar.hideTooltip(iconCell)
                  }
                  onReleased: function(m) {
                    if (dragItem.Drag.active) dragItem.Drag.drop()
                    dragItem.x = 0
                    dragItem.y = 0
                  }
                  onClicked: function(m) {
                    if (!iconCell.win) return
                    if (m.button === Qt.MiddleButton) iconCell.win.close()
                    else if (m.button === Qt.LeftButton) iconCell.win.activate()
                  }
                  onEntered: if (root.bar && iconCell.win) root.bar.showTooltip(iconCell, iconCell.win.title || iconCell.win.appId || "")
                  onExited: if (root.bar) root.bar.hideTooltip(iconCell)
                }
              }
            }
          }
        }
      }
    }

    // Drop here to send a window to the first empty workspace. Only shown mid-drag.
    Rectangle {
      id: newBox
      visible: root.dragging
      readonly property bool dropHover: newDrop.containsDrag
      width: visible ? root.cell + root.boxPad * 2 + 8 : 0
      height: visible ? root.cell + root.boxPad * 2 : 0
      radius: height / 2
      color: dropHover ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
      border.color: Commons.Color.accent
      border.width: dropHover ? 1 : 0

      Text {
        anchors.centerIn: parent
        text: "+" + root.firstEmptyWorkspace
        font.pixelSize: 11
        color: root.fg
        opacity: 0.7
      }

      DropArea {
        id: newDrop
        anchors.fill: parent
        keys: ["tasklist-window"]
        onDropped: function(drop) {
          var src = drop.source
          if (src) root.moveWindow(src.address, root.firstEmptyWorkspace)
        }
      }
    }
  }
}
