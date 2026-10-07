import AppKit
@MainActor enum MenuIcon {
    static func make(paused: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18,height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let body = NSBezierPath(roundedRect: NSRect(x: 4.5,y: 1,width: 9,height: 16),xRadius: 4.5,yRadius: 4.5); body.lineWidth = 1.4; body.stroke()
            let wheel = NSBezierPath(); wheel.move(to: NSPoint(x: 9,y: 14)); wheel.line(to: NSPoint(x: 9,y: 10)); wheel.lineWidth = 1.6; wheel.stroke()
            if paused { let slash = NSBezierPath(); slash.move(to: NSPoint(x: 2,y: 3)); slash.line(to: NSPoint(x: 16,y: 15)); slash.lineWidth = 1.4; slash.stroke() }
            return true
        }; image.isTemplate = true; return image
    }
}
