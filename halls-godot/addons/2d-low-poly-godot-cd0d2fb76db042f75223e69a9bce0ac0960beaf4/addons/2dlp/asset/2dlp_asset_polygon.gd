@tool

class_name LowPolyAsset2DPolygon
extends Resource


@export var points: Array[int];
@export var color: Color;

func equals(other: LowPolyAsset2DPolygon) -> bool:
	if len(points) != len(other.points):
		return false;
	for point in points:
		if point not in other.points:
			return false;
	return true;
