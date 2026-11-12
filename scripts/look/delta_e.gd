## CIEDE2000 colour difference (sRGB in, D65), for the look's contrast checks: both worms must stay
## distinct on every ring (under 10 would lose the worm, 20+ is comfortable). Same maths as
## art/tools/worm_looks.py de2000, so the option sheets and the game agree.
class_name DeltaE
extends RefCounted


static func lab(c: Color) -> Vector3:
	var rgb := [c.r, c.g, c.b]
	for i in 3:
		var v: float = rgb[i]
		rgb[i] = pow((v + 0.055) / 1.055, 2.4) if v > 0.04045 else v / 12.92
	var x: float = (rgb[0] * 0.4124 + rgb[1] * 0.3576 + rgb[2] * 0.1805) / 0.95047
	var y: float = rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722
	var z: float = (rgb[0] * 0.0193 + rgb[1] * 0.1192 + rgb[2] * 0.9505) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func de2000(c1: Color, c2: Color) -> float:
	var l1 := lab(c1)
	var l2 := lab(c2)
	var C1 := Vector2(l1.y, l1.z).length()
	var C2 := Vector2(l2.y, l2.z).length()
	var Cb := (C1 + C2) / 2.0
	var G := 0.5 * (1.0 - sqrt(pow(Cb, 7) / (pow(Cb, 7) + pow(25.0, 7))))
	var a1p := l1.y * (1.0 + G)
	var a2p := l2.y * (1.0 + G)
	var C1p := Vector2(a1p, l1.z).length()
	var C2p := Vector2(a2p, l2.z).length()
	var h1p := fposmod(rad_to_deg(atan2(l1.z, a1p)), 360.0)
	var h2p := fposmod(rad_to_deg(atan2(l2.z, a2p)), 360.0)
	var dLp := l2.x - l1.x
	var dCp := C2p - C1p
	var dhp := 0.0
	if C1p * C2p != 0.0:
		dhp = h2p - h1p
		if dhp > 180.0:
			dhp -= 360.0
		elif dhp < -180.0:
			dhp += 360.0
	var dHp := 2.0 * sqrt(C1p * C2p) * sin(deg_to_rad(dhp / 2.0))
	var Lbp := (l1.x + l2.x) / 2.0
	var Cbp := (C1p + C2p) / 2.0
	var hbp := h1p + h2p
	if C1p * C2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			hbp = (h1p + h2p) / 2.0
		elif h1p + h2p < 360.0:
			hbp = (h1p + h2p + 360.0) / 2.0
		else:
			hbp = (h1p + h2p - 360.0) / 2.0
	var T := 1.0 - 0.17 * cos(deg_to_rad(hbp - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hbp)) \
		+ 0.32 * cos(deg_to_rad(3.0 * hbp + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hbp - 63.0))
	var dth := 30.0 * exp(-pow((hbp - 275.0) / 25.0, 2))
	var Rc := 2.0 * sqrt(pow(Cbp, 7) / (pow(Cbp, 7) + pow(25.0, 7)))
	var Sl := 1.0 + 0.015 * pow(Lbp - 50.0, 2) / sqrt(20.0 + pow(Lbp - 50.0, 2))
	var Sc := 1.0 + 0.045 * Cbp
	var Sh := 1.0 + 0.015 * Cbp * T
	var Rt := -sin(deg_to_rad(2.0 * dth)) * Rc
	return sqrt(pow(dLp / Sl, 2) + pow(dCp / Sc, 2) + pow(dHp / Sh, 2) + Rt * (dCp / Sc) * (dHp / Sh))
