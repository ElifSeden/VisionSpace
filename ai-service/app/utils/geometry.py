def polygon_inside_image(polygon: list[list[float]], width: int, height: int) -> bool:
    return bool(polygon) and all(0 <= x <= width and 0 <= y <= height for x, y in polygon)


def polygon_area(polygon: list[list[float]]) -> float:
    if len(polygon) < 3:
        return 0.0
    area = 0.0
    for i, (x1, y1) in enumerate(polygon):
        x2, y2 = polygon[(i + 1) % len(polygon)]
        area += x1 * y2 - x2 * y1
    return abs(area) / 2.0


def _bbox(poly: list[list[float]]) -> tuple[float, float, float, float]:
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return min(xs), min(ys), max(xs), max(ys)


def polygons_overlap(poly1: list[list[float]], poly2: list[list[float]]) -> float:
    if not poly1 or not poly2:
        return 0.0
    ax1, ay1, ax2, ay2 = _bbox(poly1)
    bx1, by1, bx2, by2 = _bbox(poly2)
    ix = max(0.0, min(ax2, bx2) - max(ax1, bx1))
    iy = max(0.0, min(ay2, by2) - max(ay1, by1))
    intersection = ix * iy
    smaller = min(max((ax2 - ax1) * (ay2 - ay1), 0.0), max((bx2 - bx1) * (by2 - by1), 0.0))
    return intersection / smaller if smaller else 0.0


def clamp_polygon_to_image(polygon: list[list[float]], width: int, height: int) -> list[list[float]]:
    return [[min(max(x, 0), width), min(max(y, 0), height)] for x, y in polygon]

