/* @license
 * Copyright 2020  Dassault Systemes - All Rights Reserved.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

struct bvh_ray {
  vec3 dir;
  vec3 org;
  float tfar;
  vec3 inv_dir;
  ivec3 sign;
};

struct bvh_hit {
  int triIndex;
  float tfar;
  vec2 uv;
};

bvh_ray bvh_create_ray(in vec3 direction, in vec3 origin, in float tfar) {
  vec3 inv_direction = vec3(1.0) / direction;

  return bvh_ray(
      direction, origin, tfar, inv_direction,
      ivec3((inv_direction.x < 0.0) ? 1 : 0, (inv_direction.y < 0.0) ? 1 : 0, (inv_direction.z < 0.0) ? 1 : 0));
}

bool intersectAABB(const in bvh_ray ray, const in vec3 aabb[2], out float tmin, out float tmax) {
  float tymin, tymax, tzmin, tzmax;
  tmin = (aabb[ray.sign[0]].x - ray.org.x) * ray.inv_dir.x;
  tmax = (aabb[1 - ray.sign[0]].x - ray.org.x) * ray.inv_dir.x;
  tymin = (aabb[ray.sign[1]].y - ray.org.y) * ray.inv_dir.y;
  tymax = (aabb[1 - ray.sign[1]].y - ray.org.y) * ray.inv_dir.y;
  tzmin = (aabb[ray.sign[2]].z - ray.org.z) * ray.inv_dir.z;
  tzmax = (aabb[1 - ray.sign[2]].z - ray.org.z) * ray.inv_dir.z;
  tmin = max(max(tmin, tymin), tzmin);
  tmax = min(min(tmax, tymax), tzmax);
  return (tmin <= tmax); // we have an intersection; no intersection if tmin > tmax
}

// std. moeller trumbore triangle intersection test
bool intersectTriangle(const in bvh_ray r, in vec3 p0, in vec3 p1, in vec3 p2, const in float tfar, out float t,
                       out vec2 uv) {
  vec3 e0 = p1 - p0;
  vec3 e1 = p2 - p0;
  vec3 pvec = cross(r.dir, e1);
  float det = dot(e0, pvec);
  if (abs(det) < EPS) { // intersect backfaces
    // if(a < EPS) // skip backfaces
    return false;
  }
  float f = 1.0 / det;
  vec3 s = r.org - p0;
  float u = f * dot(s, pvec);

  if (u < 0.0 || u > 1.0)
    return false;

  vec3 qvec = cross(s, e0);
  float v = f * dot(r.dir, qvec);
  if (v < 0.0 || u + v > 1.0)
    return false;
  t = f * dot(e1, qvec);

  if (t < EPS)
    return false;

  uv = vec2(u, v);
  return (t > 0.0) && (t < tfar);
}

uint get_material_idx(const uint triIndex) {
  ivec2 idx = getStructParameterTexCoord(triIndex, 0u, TRIANGLE_STRIDE);
  return uint(texelFetch(u_sampler_triangle_data, idx, 0).w);
}

int get_mesh_triangle_index(const int bvh_tringle_index) {
  ivec2 idx = ivec2(bvh_tringle_index % int(MAX_TEXTURE_SIZE), bvh_tringle_index / int(MAX_TEXTURE_SIZE));
  return int(texelFetch(u_sampler_bvh_index, idx, 0).x);
}

void get_triangle(const in uint index, out vec3 p0, out vec3 p1, out vec3 p2) {
  ivec2 idx0 = getStructParameterTexCoord(index, POSITION_OFFSET, TRIANGLE_STRIDE);
  ivec2 idx1 = getStructParameterTexCoord(index, POSITION_OFFSET + VERTEX_STRIDE, TRIANGLE_STRIDE);
  ivec2 idx2 = getStructParameterTexCoord(index, POSITION_OFFSET + 2u * VERTEX_STRIDE, TRIANGLE_STRIDE);

  p0 = texelFetch(u_sampler_triangle_data, idx0, 0).xyz;
  p1 = texelFetch(u_sampler_triangle_data, idx1, 0).xyz;
  p2 = texelFetch(u_sampler_triangle_data, idx2, 0).xyz;
}

vec3 compute_interpolated_normal(const in uint index, const in vec2 uv) {
  ivec2 idx0 = getStructParameterTexCoord(index, NORMAL_OFFSET, TRIANGLE_STRIDE);
  ivec2 idx1 = getStructParameterTexCoord(index, NORMAL_OFFSET + VERTEX_STRIDE, TRIANGLE_STRIDE);
  ivec2 idx2 = getStructParameterTexCoord(index, NORMAL_OFFSET + 2u * VERTEX_STRIDE, TRIANGLE_STRIDE);

  vec3 n0 = texelFetch(u_sampler_triangle_data, idx0, 0).xyz;
  vec3 n1 = texelFetch(u_sampler_triangle_data, idx1, 0).xyz;
  vec3 n2 = texelFetch(u_sampler_triangle_data, idx2, 0).xyz;

  return normalize((1.0 - uv.x - uv.y) * n0 + uv.x * n1 + uv.y * n2);
}

vec2 compute_interpolated_uv(const in uint index, const in vec2 hit_uv, int set) {
  ivec2 idx0 = getStructParameterTexCoord(index, UV_OFFSET, TRIANGLE_STRIDE);
  ivec2 idx1 = getStructParameterTexCoord(index, UV_OFFSET + VERTEX_STRIDE, TRIANGLE_STRIDE);
  ivec2 idx2 = getStructParameterTexCoord(index, UV_OFFSET + 2u * VERTEX_STRIDE, TRIANGLE_STRIDE);

  vec4 uv0 = texelFetch(u_sampler_triangle_data, idx0, 0);
  vec4 uv1 = texelFetch(u_sampler_triangle_data, idx1, 0);
  vec4 uv2 = texelFetch(u_sampler_triangle_data, idx2, 0);

  if (set == 0) {
    return (1.0 - hit_uv.x - hit_uv.y) * uv0.xy + hit_uv.x * uv1.xy + hit_uv.y * uv2.xy;
  } else {
    return (1.0 - hit_uv.x - hit_uv.y) * uv0.zw + hit_uv.x * uv1.zw + hit_uv.y * uv2.zw;
  }
}

vec4 compute_interpolated_tangent(const in uint index, const in vec2 uv, vec3 n) {
  ivec2 idx0 = getStructParameterTexCoord(index, TANGENT_OFFSET, TRIANGLE_STRIDE);
  ivec2 idx1 = getStructParameterTexCoord(index, TANGENT_OFFSET + VERTEX_STRIDE, TRIANGLE_STRIDE);
  ivec2 idx2 = getStructParameterTexCoord(index, TANGENT_OFFSET + 2u * VERTEX_STRIDE, TRIANGLE_STRIDE);

  vec4 t0 = texelFetch(u_sampler_triangle_data, idx0, 0);
  vec4 t1 = texelFetch(u_sampler_triangle_data, idx1, 0);
  vec4 t2 = texelFetch(u_sampler_triangle_data, idx2, 0);

  float handedness = (t0.w == t1.w && t0.w == t2.w) ? t0.w : 0.0;
  vec3 tangent = normalize((1.0 - uv.x - uv.y) * t0.xyz + uv.x * t1.xyz + uv.y * t2.xyz);

  vec4 ret;
  // TODO ensure proper tangents when parsing the scene on CPU
  if (length(tangent) > 0.99 && abs(handedness) > 0.99) {
    ret = vec4(tangent, -handedness);
  } else {
    ret = vec4(get_onb(n)[0], 1.0);
  }

  return ret;
}

vec4 calculateInterpolatedVertexColors(const in uint index, const in vec2 hit_uv) {
  ivec2 idx0 = getStructParameterTexCoord(index, COLOR_OFFSET, TRIANGLE_STRIDE);
  ivec2 idx1 = getStructParameterTexCoord(index, COLOR_OFFSET + VERTEX_STRIDE, TRIANGLE_STRIDE);
  ivec2 idx2 = getStructParameterTexCoord(index, COLOR_OFFSET + 2u * VERTEX_STRIDE, TRIANGLE_STRIDE);
  vec4 c0 = texelFetch(u_sampler_triangle_data, idx0, 0);
  vec4 c1 = texelFetch(u_sampler_triangle_data, idx1, 0);
  vec4 c2 = texelFetch(u_sampler_triangle_data, idx2, 0);

  return (1.0 - hit_uv.x - hit_uv.y) * c0 + hit_uv.x * c1 + hit_uv.y * c2;
}

bool bvh_IntersectRayBox(const in bvh_ray r, const in float tfar, int pn, out int si, out int ei) {
  int idx_x0 = int(pn * 2 + 0) % int(MAX_TEXTURE_SIZE);
  int idx_y0 = int(pn * 2 + 0) / int(MAX_TEXTURE_SIZE);

  int idx_x1 = int(pn * 2 + 1) % int(MAX_TEXTURE_SIZE);
  int idx_y1 = int(pn * 2 + 1) / int(MAX_TEXTURE_SIZE);

  vec4 nodeA = texelFetch(u_sampler_bvh, ivec2(idx_x0, idx_y0), 0);
  vec4 nodeB = texelFetch(u_sampler_bvh, ivec2(idx_x1, idx_y1), 0);
  vec3 aabb[2];
  aabb[0] = nodeA.xyz;
  aabb[1] = nodeB.xyz;
  si = int(nodeA.w);
  ei = int(nodeB.w);

  float tmin, tmax;
  bool hasHit = intersectAABB(r, aabb, tmin, tmax);

  //!!TODO: check if this has correct semantics for rays that start inside the box?
  return hasHit && ((/*tmin > 0.0 && */ tmin <= tfar) || (tmin < 0.0 && tmax <= tfar));
}

/*!!TODO/!!TOOPT:
    - sort out the many tfars
    - sort the needed data in ray payload and return values
*/
bool intersectSceneTriangles_BVH(const in bvh_ray r, out bvh_hit hit) {
  hit.tfar = r.tfar;
  hit.triIndex = -1;

  int stack[64];
  int top = 1;
  int pn = 0;

  float tfar = r.tfar;
  bool foundHit = false;
  int si, ei;

  while (top > 0 && top < 32) {
    if (bvh_IntersectRayBox(r, tfar, pn, si, ei)) {

      if (si > 0) { // intermediate node
        // !!TOOPT: sort front to back based on ray sign (but this needs additional data in nodes based on construction)
        pn = si;
        stack[top++] = ei;
      } else { // leaf node
        for (int i = -si; i < -ei; i++) {
          float t = 0.0;
          vec2 uv;
          vec3 p0, p1, p2;
          int idx = get_mesh_triangle_index(i);
          get_triangle(uint(idx), p0, p1, p2);
          if (intersectTriangle(r, p0, p1, p2, hit.tfar, t, uv)) {
            hit.tfar = t;
            hit.triIndex = idx;
            hit.uv = uv;
            foundHit = true;
            tfar = t;
          }
        }

        pn = stack[--top];
      }

    } else {
      pn = stack[--top];
    }
  }

  return foundHit;
}

bool intersectSceneTriangles_Bruteforce(const in bvh_ray r, out bvh_hit hit) {
  hit.tfar = r.tfar;
  hit.triIndex = -1;

  for (int i = 0; i < int(NUM_TRIANGLES); i++) {
    vec3 p0, p1, p2;

    int idx = get_mesh_triangle_index(i);
    get_triangle(uint(i), p0, p1, p2);

    float t = 0.0;
    vec2 uv;
    if (intersectTriangle(r, p0, p1, p2, hit.tfar, t, uv)) {
      // if(t < hit.tfar) {
      hit.tfar = t;
      hit.triIndex = i;
      hit.uv = uv;
      // }
    }
  }

  return hit.triIndex >= 0;
}

bool bvh_intersect_nearest(const in bvh_ray r, out bvh_hit hit) {
  // return intersectSceneTriangles_Bruteforce(r, hit);
  return intersectSceneTriangles_BVH(r, hit);
}

bool isVisible(const in vec3 p0, const in vec3 p1) {
  bvh_ray r = bvh_create_ray(normalize(p1 - p0), p0, length(p1 - p0));
  bvh_hit hit;
  return !bvh_intersect_nearest(r, hit); //!!TOOPT: add an early hit function here
}

bool isOccluded(const in vec3 p0, const in vec3 dir) {
  bvh_ray r = bvh_create_ray(normalize(dir), p0, TFAR_MAX);
  bvh_hit hit;
  return bvh_intersect_nearest(r, hit); //!!TOOPT: add an early hit function here
}
