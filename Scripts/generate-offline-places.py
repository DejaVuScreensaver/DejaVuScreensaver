#!/usr/bin/env python3
"""Build the compact offline place database from Natural Earth GeoJSON files."""

import argparse
import json
import plistlib

SCALE = 10_000
SIMPLIFICATION_TOLERANCE = 0.005


def rdp(points, tolerance):
    if len(points) <= 2:
        return points
    start, end = points[0], points[-1]
    dx, dy = end[0] - start[0], end[1] - start[1]
    denominator = dx * dx + dy * dy
    furthest_index, furthest_distance = 0, -1
    for index, point in enumerate(points[1:-1], 1):
        if denominator == 0:
            distance = (point[0] - start[0]) ** 2 + (point[1] - start[1]) ** 2
        else:
            position = ((point[0] - start[0]) * dx + (point[1] - start[1]) * dy) / denominator
            projection = (start[0] + position * dx, start[1] + position * dy)
            distance = (point[0] - projection[0]) ** 2 + (point[1] - projection[1]) ** 2
        if distance > furthest_distance:
            furthest_index, furthest_distance = index, distance
    if furthest_distance > tolerance * tolerance:
        return rdp(points[:furthest_index + 1], tolerance)[:-1] + rdp(points[furthest_index:], tolerance)
    return [start, end]


def simplify_ring(ring):
    points = ring[:-1] if ring[0] == ring[-1] else ring
    if len(points) <= 4:
        return points
    split = max(
        range(1, len(points)),
        key=lambda index: (points[index][0] - points[0][0]) ** 2 + (points[index][1] - points[0][1]) ** 2,
    )
    first = rdp(points[:split + 1], SIMPLIFICATION_TOLERANCE)
    second = rdp(points[split:] + [points[0]], SIMPLIFICATION_TOLERANCE)
    simplified = first[:-1] + second[:-1]
    return simplified if len(simplified) >= 3 else points


def encode_ring(ring):
    points = [
        (round(point[0] * SCALE), round(point[1] * SCALE))
        for point in simplify_ring(ring)
    ]
    encoded = [points[0][0], points[0][1]]
    previous = points[0]
    for point in points[1:]:
        encoded.extend((point[0] - previous[0], point[1] - previous[1]))
        previous = point
    return encoded


def encode_geometry(geometry):
    polygons = [geometry["coordinates"]] if geometry["type"] == "Polygon" else geometry["coordinates"]
    return [[encode_ring(ring) for ring in polygon] for polygon in polygons]


def feature_bbox(feature):
    bbox = feature.get("bbox")
    if bbox:
        return [round(value * SCALE) for value in bbox]
    points = []
    polygons = [feature["geometry"]["coordinates"]] if feature["geometry"]["type"] == "Polygon" else feature["geometry"]["coordinates"]
    for polygon in polygons:
        for ring in polygon:
            points.extend(ring)
    return [
        round(min(point[0] for point in points) * SCALE),
        round(min(point[1] for point in points) * SCALE),
        round(max(point[0] for point in points) * SCALE),
        round(max(point[1] for point in points) * SCALE),
    ]


def load(path):
    with open(path, encoding="utf-8") as source:
        return json.load(source)["features"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cities", required=True)
    parser.add_argument("--regions", required=True)
    parser.add_argument("--countries", required=True)
    parser.add_argument("--output", required=True)
    arguments = parser.parse_args()

    cities = []
    for feature in load(arguments.cities):
        properties = feature["properties"]
        longitude, latitude = feature["geometry"]["coordinates"]
        cities.append({
            "n": properties.get("name") or properties.get("nameascii"),
            "x": round(longitude * SCALE),
            "y": round(latitude * SCALE),
        })

    def areas(path, name_key, country_key):
        result = []
        for feature in load(path):
            properties = feature["properties"]
            name = properties.get(name_key) or properties.get("name") or properties.get("NAME")
            if not name:
                continue
            item = {
                "n": name,
                "b": feature_bbox(feature),
                "p": encode_geometry(feature["geometry"]),
            }
            country = properties.get(country_key)
            if country and country != name:
                item["c"] = country
            result.append(item)
        return result

    database = {
        "c": cities,
        "r": areas(arguments.regions, "name_en", "admin"),
        "n": areas(arguments.countries, "NAME_EN", "ADMIN"),
    }
    with open(arguments.output, "wb") as output:
        plistlib.dump(database, output, fmt=plistlib.FMT_BINARY, sort_keys=False)


if __name__ == "__main__":
    main()
