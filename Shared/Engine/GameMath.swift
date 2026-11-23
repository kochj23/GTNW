//
//  GameMath.swift
//  GTNW
//
//  The elementary functions the simulation uses (pow, log10, log2, sin, cos, asin, atan2, hypot), computed the same
//  way on every platform. The C library's versions differ in the last bit between Apple's libm and the musl libm
//  that WebAssembly links (pow differs on about 1 input in 600, sin and cos on 1 in 25, hypot and atan2 on 1 in 8),
//  and a last-bit difference in a GDP or a growth factor turned into a different approval figure within 20 to 35
//  turns of the WebAssembly soak (Wasm/parity/soak.mjs). These use only IEEE 754 addition, multiplication, division
//  and square root, which every platform rounds alike (Swift never fuses a multiply and an add on its own), so the
//  app, the SwiftPM core and the WebAssembly build get the same bits.
//
//  The algorithms are FreeBSD's msun (fdlibm) ones, accurate to about one unit in the last place:
//
//    Copyright (C) 1993 by Sun Microsystems, Inc. All rights reserved.
//    Developed at SunPro, a Sun Microsystems, Inc. business.
//    Permission to use, copy, modify, and distribute this software is freely granted, provided that this notice
//    is preserved.
//
//  Simulation code calls `GameMath.*` instead of the C library (EssentialsTests checks the engine sources for bare
//  calls). Views may use the C library: what they compute is never part of the game.
//

import Foundation

enum GameMath {

    // MARK: Bits

    @inline(__always) private static func high(_ x: Double) -> Int32 { Int32(truncatingIfNeeded: Int64(bitPattern: x.bitPattern) >> 32) }
    @inline(__always) private static func low(_ x: Double) -> UInt32 { UInt32(truncatingIfNeeded: x.bitPattern) }
    @inline(__always) private static func make(high: Int32, low: UInt32) -> Double {
        Double(bitPattern: UInt64(UInt32(bitPattern: high)) << 32 | UInt64(low))
    }
    /// x · 2ⁿ, exactly (for results in the normal range; the simulation never leaves it).
    private static func scale(_ x: Double, _ n: Int) -> Double {
        var x = x, n = n
        while n > 1023 { x *= 0x1p1023; n -= 1023 }
        while n < -1022 { x *= 0x1p-1022; n += 1022 }
        return x * Double(sign: .plus, exponent: n, significand: 1)
    }

    // MARK: exp and log

    private static let ln2Hi = 6.93147180369123816490e-01, ln2Lo = 1.90821492927058770002e-10
    private static let invLn2 = 1.44269504088896338700e+00

    /// e^x (msun e_exp.c).
    static func exp(_ x: Double) -> Double {
        if x.isNaN { return x }
        if x > 7.09782712893383973096e+02 { return .infinity }
        if x < -7.45133219101941108420e+02 { return 0 }
        let ax = abs(x), negative = x < 0
        var hi = 0.0, lo = 0.0, k = 0, r = x
        if ax > 0.5 * 6.93147180559945286227e-01 {
            if ax < 1.5 * 6.93147180559945286227e-01 {
                hi = negative ? x + ln2Hi : x - ln2Hi
                lo = negative ? -ln2Lo : ln2Lo
                k = negative ? -1 : 1
            } else {
                k = Int(invLn2 * x + (negative ? -0.5 : 0.5))
                let t = Double(k)
                hi = x - t * ln2Hi
                lo = t * ln2Lo
            }
            r = hi - lo
        } else if ax < 0x1p-28 {
            return 1 + x
        }
        let t = r * r
        let c = r - t * (1.66666666666666019037e-01 + t * (-2.77777777770155933842e-03 + t * (6.61375632143793436117e-05
                + t * (-1.65339022054652515390e-06 + t * 4.13813679705723846039e-08))))
        if k == 0 { return 1 - ((r * c) / (c - 2) - r) }
        return scale(1 - ((lo - (r * c) / (2 - c)) - hi), k)
    }

    /// Natural logarithm (msun e_log.c).
    static func log(_ x: Double) -> Double {
        var x = x
        var hx = high(x)
        let lx = low(x)
        var k: Int32 = 0
        if hx < 0x0010_0000 {
            if (hx & 0x7fff_ffff) == 0 && lx == 0 { return -.infinity }
            if hx < 0 { return .nan }
            k -= 54
            x *= 1.80143985094819840000e+16
            hx = high(x)
        }
        if hx >= 0x7ff0_0000 { return x + x }
        k += (hx >> 20) - 1023
        hx &= 0x000f_ffff
        let i0 = (hx &+ 0x95f64) & 0x10_0000
        x = make(high: hx | (i0 ^ 0x3ff0_0000), low: low(x))
        k += i0 >> 20
        let f = x - 1
        let dk = Double(k)
        if (0x000f_ffff & (2 &+ hx)) < 3 {
            if f == 0 { return k == 0 ? 0 : dk * ln2Hi + dk * ln2Lo }
            let r = f * f * (0.5 - 0.33333333333333333 * f)
            return k == 0 ? f - r : dk * ln2Hi - ((r - dk * ln2Lo) - f)
        }
        let s = f / (2 + f)
        let z = s * s
        var i = hx &- 0x6147a
        let w = z * z
        let j = 0x6b851 &- hx
        let t1 = w * (3.999999999940941908e-01 + w * (2.222219843214978396e-01 + w * 1.531383769920937332e-01))
        let t2 = z * (6.666666666666735130e-01 + w * (2.857142874366239149e-01 + w * (1.818357216161805012e-01 + w * 1.479819860511658591e-01)))
        i |= j
        let r = t2 + t1
        if i > 0 {
            let hfsq = 0.5 * f * f
            return k == 0 ? f - (hfsq - s * (hfsq + r)) : dk * ln2Hi - ((hfsq - (s * (hfsq + r) + dk * ln2Lo)) - f)
        }
        return k == 0 ? f - s * (f - r) : dk * ln2Hi - ((s * (f - r) - dk * ln2Lo) - f)
    }

    /// Splits a positive finite x into m · 2ᵏ with m in [√2/2, √2).
    private static func split(_ x: Double) -> (m: Double, k: Int) {
        var x = x, k = 0
        if x < 0x1p-1022 { x *= 0x1p54; k = -54 }
        var e = Int((x.bitPattern >> 52) & 0x7ff) - 1023
        var m = Double(bitPattern: (x.bitPattern & 0x000f_ffff_ffff_ffff) | 0x3ff0_0000_0000_0000)
        if m >= 1.41421356237309504880 { m *= 0.5; e += 1 }
        return (m, k + e)
    }

    /// Base-10 logarithm: k·log10(2) + log10(m), the constant split in two for exact powers of two.
    static func log10(_ x: Double) -> Double {
        guard x > 0, x.isFinite else { return x == 0 ? -.infinity : (x == .infinity ? x : .nan) }
        let (m, k) = split(x)
        let y = Double(k)
        return y * 3.01029995663611771306e-01 + (y * 3.69423907715893078616e-13 + 4.34294481903251816668e-01 * log(m))
    }

    /// Base-2 logarithm: k + log2(m) (exact for powers of two).
    static func log2(_ x: Double) -> Double {
        guard x > 0, x.isFinite else { return x == 0 ? -.infinity : (x == .infinity ? x : .nan) }
        let (m, k) = split(x)
        return Double(k) + log(m) * invLn2
    }

    /// xʸ. Integer powers up to 64 multiply out (so 10⁻³ and x² are exact or correctly rounded where the C library's
    /// are), y = ½ is the square root, and the rest is e^(y·ln x) with the rounding carried.
    static func pow(_ x: Double, _ y: Double) -> Double {
        if y == 0 || x == 1 { return 1 }
        if x.isNaN || y.isNaN { return .nan }
        if y == 1 { return x }
        if y.rounded() == y, abs(y) <= 64 {
            var n = Int(abs(y)), base = x, result = 1.0
            while n > 0 {
                if n & 1 == 1 { result *= base }
                n >>= 1
                if n > 0 { base *= base }
            }
            return y < 0 ? 1 / result : result
        }
        if x == 0 { return y > 0 ? 0 : .infinity }
        if x < 0 { return .nan }
        if y == 0.5, x.isFinite { return x.squareRoot() }
        if x == .infinity { return y > 0 ? .infinity : 0 }
        // e^(y·ln x), with ln x and the product carried as unevaluated sums (Dekker), so the result is as good as exp.
        let (lh, ll) = logExtended(x)
        let (p, pe) = product(y, lh)
        if p > 709.78 { return .infinity }
        if p < -745.14 { return 0 }
        let e = exp(p)
        return e + e * (pe + y * ll)
    }

    /// ln x as hi + lo (x positive, finite): msun's log, its terms summed without dropping the low bits.
    private static func logExtended(_ x: Double) -> (Double, Double) {
        let (m, k) = split(x)
        let f = m - 1, dk = Double(k)
        let s = f / (2 + f), z = s * s, w = z * z
        let r = z * (6.666666666666735130e-01 + w * (2.857142874366239149e-01 + w * (1.818357216161805012e-01 + w * 1.479819860511658591e-01)))
            + w * (3.999999999940941908e-01 + w * (2.222219843214978396e-01 + w * 1.531383769920937332e-01))
        let (f2, f2e) = product(f, f)
        let hfsq = 0.5 * f2   // exact
        // ln x = k·ln2_hi + f − f²/2 + s·(f²/2 + R) + k·ln2_lo
        var (hi, lo) = twoSum(dk * ln2Hi, f)
        (hi, lo) = addTo(hi, lo, -hfsq)
        lo += -0.5 * f2e + (s * (hfsq + r) + dk * ln2Lo)
        return twoSum(hi, lo)
    }

    /// a + b as hi + lo, exactly (Knuth).
    private static func twoSum(_ a: Double, _ b: Double) -> (Double, Double) {
        let s = a + b, bb = s - a
        return (s, (a - (s - bb)) + (b - bb))
    }

    private static func addTo(_ hi: Double, _ lo: Double, _ b: Double) -> (Double, Double) {
        let (s, e) = twoSum(hi, b)
        return (s, e + lo)
    }

    /// a·b as an unevaluated sum hi + lo, exactly (Dekker; no fused multiply-add, which WebAssembly lacks).
    private static func product(_ a: Double, _ b: Double) -> (Double, Double) {
        let p = a * b
        func split(_ v: Double) -> (Double, Double) {
            let c = 134_217_729.0 * v
            let hi = c - (c - v)
            return (hi, v - hi)
        }
        let (ah, al) = split(a), (bh, bl) = split(b)
        return (p, ((ah * bh - p) + ah * bl + al * bh) + al * bl)
    }

    // MARK: Trigonometry

    private static func kernelSin(_ x: Double, _ y: Double, _ hasTail: Bool) -> Double {
        if abs(x) < 0x1p-27 { return x }
        let z = x * x, v = z * x
        let r = 8.33333333332248946124e-03 + z * (-1.98412698298579493134e-04 + z * (2.75573137070700676789e-06
                + z * (-2.50507602534068634195e-08 + z * 1.58969099521155010221e-10)))
        if !hasTail { return x + v * (-1.66666666666666324348e-01 + z * r) }
        return x - ((z * (0.5 * y - v * r) - y) - v * -1.66666666666666324348e-01)
    }

    private static func kernelCos(_ x: Double, _ y: Double) -> Double {
        let ix = high(x) & 0x7fff_ffff
        if ix < 0x3e40_0000 { return 1 }
        let z = x * x
        let r = z * (4.16666666666666019037e-02 + z * (-1.38888888888741095749e-03 + z * (2.48015872894767294178e-05
                + z * (-2.75573143513906633035e-07 + z * (2.08757232129817482790e-09 + z * -1.13596475577881948265e-11)))))
        if ix < 0x3fd3_3333 { return 1 - (0.5 * z - (z * r - x * y)) }
        let qx = ix > 0x3fe9_0000 ? 0.28125 : make(high: ix - 0x0020_0000, low: 0)
        let hz = 0.5 * z - qx
        return (1 - qx) - (hz - (z * r - x * y))
    }

    /// x reduced by multiples of π/2: x = n·π/2 + (y0 + y1) (msun's medium-size reduction, three-part π/2).
    private static func reduce(_ x: Double) -> (n: Int, y0: Double, y1: Double) {
        // Far outside anything the game computes: bring it within 2π first (exactly), at some cost in accuracy.
        if abs(x) > 0x1p30 { return reduce(x.truncatingRemainder(dividingBy: 6.28318530717958647692)) }
        let t = abs(x)
        let n = Int(t * 6.36619772367581382433e-01 + 0.5)
        let fn = Double(n)
        var r = t - fn * 1.57079632673412561417e+00
        var w = fn * 6.07710050650619224932e-11
        let j = Int(high(t) >> 20)
        var y0 = r - w
        var i = j - Int((high(y0) >> 20) & 0x7ff)
        if i > 16 {
            var u = r
            w = fn * 6.07710050630396597660e-11
            r = u - w
            w = fn * 2.02226624879595063154e-21 - ((u - r) - w)
            y0 = r - w
            i = j - Int((high(y0) >> 20) & 0x7ff)
            if i > 49 {
                u = r
                w = fn * 2.02226624871116645580e-21
                r = u - w
                w = fn * 8.47842766036889956997e-32 - ((u - r) - w)
                y0 = r - w
            }
        }
        let y1 = (r - y0) - w
        return x < 0 ? (-n, -y0, -y1) : (n, y0, y1)
    }

    static func sin(_ x: Double) -> Double {
        if !x.isFinite { return x - x }
        if abs(x) <= 7.85398163397448278999e-01 { return kernelSin(x, 0, false) }
        let (n, y0, y1) = reduce(x)
        switch n & 3 {
        case 0: return kernelSin(y0, y1, true)
        case 1: return kernelCos(y0, y1)
        case 2: return -kernelSin(y0, y1, true)
        default: return -kernelCos(y0, y1)
        }
    }

    static func cos(_ x: Double) -> Double {
        if !x.isFinite { return x - x }
        if abs(x) <= 7.85398163397448278999e-01 { return kernelCos(x, 0) }
        let (n, y0, y1) = reduce(x)
        switch n & 3 {
        case 0: return kernelCos(y0, y1)
        case 1: return -kernelSin(y0, y1, true)
        case 2: return -kernelCos(y0, y1)
        default: return kernelSin(y0, y1, true)
        }
    }

    private static let pio2Hi = 1.57079632679489655800e+00, pio2Lo = 6.12323399573676603587e-17
    private static let pio4Hi = 7.85398163397448278999e-01

    private static func asinRatio(_ t: Double) -> Double {
        let p = t * (1.66666666666666657415e-01 + t * (-3.25565818622400915405e-01 + t * (2.01212532134862925881e-01
                + t * (-4.00555345006794114027e-02 + t * (7.91534994289814532176e-04 + t * 3.47933107596021167570e-05)))))
        let q = 1 + t * (-2.40339491173441421878e+00 + t * (2.02094576023350569471e+00 + t * (-6.88283971605453293030e-01
                + t * 7.70381505559019352791e-02)))
        return p / q
    }

    /// Arcsine (msun e_asin.c).
    static func asin(_ x: Double) -> Double {
        let ax = abs(x)
        if ax >= 1 { return ax == 1 ? x * pio2Hi + x * pio2Lo : .nan }
        if ax < 0.5 {
            if ax < 0x1p-27 { return x }
            return x + x * asinRatio(x * x)
        }
        let t = (1 - ax) * 0.5
        let s = t.squareRoot()
        var result: Double
        if ax >= 0.975 {
            result = pio2Hi - (2 * (s + s * asinRatio(t)) - pio2Lo)
        } else {
            let w = Double(bitPattern: s.bitPattern & 0xffff_ffff_0000_0000)
            let c = (t - w * w) / (s + w)
            let p = 2 * s * asinRatio(t) - (pio2Lo - 2 * c)
            let q = pio4Hi - 2 * w
            result = pio4Hi - (p - q)
        }
        return x > 0 ? result : -result
    }

    private static let atanHi = [4.63647609000806093515e-01, 7.85398163397448278999e-01, 9.82793723247329054082e-01, 1.57079632679489655800e+00]
    private static let atanLo = [2.26987774529616870924e-17, 3.06161699786838301793e-17, 1.39033110312309984516e-17, 6.12323399573676603587e-17]

    /// Arctangent (msun s_atan.c).
    static func atan(_ x: Double) -> Double {
        let hx = high(x), ix = hx & 0x7fff_ffff
        if ix >= 0x4410_0000 {
            if x.isNaN { return x + x }
            return hx > 0 ? atanHi[3] + atanLo[3] : -atanHi[3] - atanLo[3]
        }
        var id = -1, v = x
        if ix < 0x3fdc_0000 {
            if ix < 0x3e20_0000 { return x }
        } else {
            v = abs(x)
            if ix < 0x3ff3_0000 {
                if ix < 0x3fe6_0000 { id = 0; v = (2 * v - 1) / (2 + v) } else { id = 1; v = (v - 1) / (v + 1) }
            } else {
                if ix < 0x4003_8000 { id = 2; v = (v - 1.5) / (1 + 1.5 * v) } else { id = 3; v = -1 / v }
            }
        }
        let z = v * v, w = z * z
        let s1 = z * (3.33333333333329318027e-01 + w * (1.42857142725034663711e-01 + w * (9.09088713343650656196e-02
                 + w * (6.66107313738753120669e-02 + w * (4.97687799461593236017e-02 + w * 1.62858201153657823623e-02)))))
        let s2 = w * (-1.99999999998764832476e-01 + w * (-1.11111104054623557880e-01 + w * (-7.69187620504482999495e-02
                 + w * (-5.83357013379057348645e-02 + w * -3.65315727442169155270e-02))))
        if id < 0 { return v - v * (s1 + s2) }
        let r = atanHi[id] - ((v * (s1 + s2) - atanLo[id]) - v)
        return hx < 0 ? -r : r
    }

    /// atan(y/x) in the right quadrant (msun e_atan2.c).
    static func atan2(_ y: Double, _ x: Double) -> Double {
        let pi = 3.1415926535897931160e+00, piLo = 1.2246467991473531772e-16
        if x.isNaN || y.isNaN { return x + y }
        if x == 1 { return atan(y) }
        let m = (y.sign == .minus ? 1 : 0) | (x.sign == .minus ? 2 : 0)
        if y == 0 {
            switch m {
            case 0, 1: return y
            case 2: return pi
            default: return -pi
            }
        }
        if x == 0 { return y < 0 ? -pio2Hi : pio2Hi }
        if x.isInfinite {
            if y.isInfinite { return [pio4Hi, -pio4Hi, 3 * pio4Hi, -3 * pio4Hi][m] }
            return [0, -0.0, pi, -pi][m]
        }
        if y.isInfinite { return y < 0 ? -pio2Hi : pio2Hi }
        let k = Int((high(y) & 0x7ff0_0000) >> 20) - Int((high(x) & 0x7ff0_0000) >> 20)
        let z: Double
        if k > 60 { z = pio2Hi + 0.5 * piLo } else if x < 0 && k < -60 { z = 0 } else { z = atan(abs(y / x)) }
        switch m {
        case 0: return z
        case 1: return -z
        case 2: return pi - (z - piLo)
        default: return (z - piLo) - pi
        }
    }

    /// √(x² + y²), scaled only where the squares would leave the normal range.
    static func hypot(_ x: Double, _ y: Double) -> Double {
        if x.isInfinite || y.isInfinite { return .infinity }
        if x.isNaN || y.isNaN { return .nan }
        var a = abs(x), b = abs(y)
        if a < b { swap(&a, &b) }
        if a == 0 { return 0 }
        if a < 0x1p500 && b > 0x1p-500 { return (a * a + b * b).squareRoot() }
        let r = b / a
        return a * (1 + r * r).squareRoot()
    }
}
