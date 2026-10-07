import SwiftUI

/// Vector re-drawing of the Aura Med mark: an apothecary arch holding a capsule and a leaf.
struct LogoMark: View {
    var color: Color = Color(hex: 0x7C9082)
    var accent: Color = Color(hex: 0xC97F5E)
    var lineWidth: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let style = StrokeStyle(lineWidth: max(1, lineWidth * s / 40), lineCap: .round, lineJoin: .round)
            ZStack {
                LogoArch().stroke(color, style: style)
                LogoCapsule().stroke(color, style: style)
                LogoLeaf().stroke(color, style: style)
                LogoAccent().stroke(accent, style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, dash: [s * 0.06, s * 0.05]))
            }
            .frame(width: s, height: s)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension CGRect {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: minX + width * x / 100, y: minY + height * y / 100)
    }
    func l(_ v: CGFloat) -> CGFloat { width * v / 100 }
}

struct LogoArch: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Left leg up, arch over the top, right leg down.
        p.move(to: r.p(28, 64))
        p.addLine(to: r.p(28, 36))
        p.addArc(center: r.p(50, 36), radius: r.l(22), startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: r.p(72, 92 - 28))
        // Base on the right side
        p.move(to: r.p(72, 64))
        p.addLine(to: r.p(47, 64))
        // Base on the left side, where the leaf stem sweeps in
        p.move(to: r.p(28, 64))
        p.addLine(to: r.p(33, 64))
        p.addQuadCurve(to: r.p(46, 57), control: r.p(41, 64))
        return p
    }
}

struct LogoCapsule: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let left: CGFloat = 38, right: CGFloat = 53
        let top: CGFloat = 23, bottom: CGFloat = 57
        let rad = (right - left) / 2
        p.move(to: r.p(left, bottom - rad))
        p.addLine(to: r.p(left, top + rad))
        p.addArc(center: r.p(left + rad, top + rad), radius: r.l(rad), startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: r.p(right, 40))
        // Mid seam
        p.move(to: r.p(left, 41))
        p.addLine(to: r.p(51, 41))
        // Lower left curve
        p.move(to: r.p(left, bottom - rad))
        p.addQuadCurve(to: r.p(44, bottom), control: r.p(left, bottom))
        return p
    }
}

struct LogoLeaf: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Leaf outline
        p.move(to: r.p(46, 57))
        p.addCurve(to: r.p(60, 39), control1: r.p(44, 48), control2: r.p(50, 41))
        p.addCurve(to: r.p(49, 58), control1: r.p(60, 48), control2: r.p(56, 55))
        // Midrib
        p.move(to: r.p(46, 57))
        p.addLine(to: r.p(55, 47))
        return p
    }
}

struct LogoAccent: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: r.p(44, 26.5))
        p.addQuadCurve(to: r.p(41.5, 30), control: r.p(41.5, 26.5))
        p.addLine(to: r.p(41.5, 38))
        p.move(to: r.p(41.5, 50))
        p.addQuadCurve(to: r.p(44, 54), control: r.p(41.5, 54))
        return p
    }
}

#Preview {
    LogoMark()
        .frame(width: 240, height: 240)
        .background(Aura.surface)
}
