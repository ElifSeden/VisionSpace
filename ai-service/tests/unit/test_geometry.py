from app.utils.geometry import clamp_polygon_to_image, polygon_area, polygon_inside_image, polygons_overlap


def test_polygon_area() -> None:
    assert polygon_area([[0, 0], [10, 0], [10, 10], [0, 10]]) == 100


def test_polygon_inside_image() -> None:
    assert polygon_inside_image([[0, 0], [10, 10]], 20, 20)
    assert not polygon_inside_image([[0, 0], [30, 10]], 20, 20)


def test_clamp_polygon_to_image() -> None:
    assert clamp_polygon_to_image([[-1, 5], [30, 40]], 20, 20) == [[0, 5], [20, 20]]


def test_polygons_overlap_bbox_ratio() -> None:
    assert polygons_overlap([[0, 0], [10, 0], [10, 10], [0, 10]], [[5, 5], [15, 5], [15, 15], [5, 15]]) == 0.25

