@tool

class_name LowPolyAsset2DEdge
extends Resource

@export var a: int;
@export var b: int;

func equals(other: LowPolyAsset2DEdge) -> bool:
	return a == other.a and b == other.b or a == other.b and b == other.a;
