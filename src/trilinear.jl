export make_coordinate_matrix, make_inverse_coordinate_matrix, make_drr, raytrace_trilinear, make_plane, get_rays, interpolate

using LinearAlgebra


function make_coordinate_matrix(x0, y0, z0, x1, y1, z1)
    M = [
        1 x0 y0 z0 x0*y0 x0*z0 y0*z0 x0*y0*z0
        1 x1 y0 z0 x1*y0 x1*z0 y0*z0 x1*y0*z0
        1 x0 y1 z0 x0*y1 x0*z0 y1*z0 x0*y1*z0
        1 x0 y1 z1 x0*y1 x0*z1 y1*z1 x0*y1*z1
        1 x0 y0 z1 x0*y0 x0*z1 y0*z1 x0*y0*z1
        1 x1 y0 z1 x1*y0 x1*z1 y0*z1 x1*y0*z1
        1 x1 y1 z0 x1*y1 x1*z0 y1*z0 x1*y1*z0
        1 x1 y1 z1 x1*y1 x1*z1 y1*z1 x1*y1*z1
    ]
    return M
end


function make_inverse_coordinate_matrix(x0, y0, z0, x1, y1, z1)
    volume = (x1 - x0) * (y1 - y0) * (z1 - z0)
    Minv = [
        x1*y1*z1 -x0*y1*z1 -x1*y0*z1 x1*y0*z0 -x1*y1*z0 x0*y1*z0 x0*y0*z1 -x0*y0*z0
        -y1*z1 y1*z1 y0*z1 -y0*z0 y1*z0 -y1*z0 -y0*z1 y0*z0
        -x1*z1 x0*z1 x1*z1 -x1*z0 x1*z0 -x0*z0 -x0*z1 x0*z0
        -x1*y1 x0*y1 x1*y0 -x1*y0 x1*y1 -x0*y1 -x0*y0 x0*y0
        z1 -z1 -z1 z0 -z0 z0 z1 -z0
        y1 -y1 -y0 y0 -y1 y1 y0 -y0
        x1 -x0 -x1 x1 -x1 x0 x0 -x0
        -1 1 1 -1 1 -1 -1 1
    ]
    return Minv / volume
end


function get_colors(volume, xidx, yidx, zidx)
    c000 = volume[xidx, yidx, zidx]
    c100 = volume[xidx+1, yidx, zidx]
    c010 = volume[xidx, yidx+1, zidx]
    c110 = volume[xidx+1, yidx+1, zidx]
    c001 = volume[xidx, yidx, zidx+1]
    c101 = volume[xidx+1, yidx, zidx+1]
    c110 = volume[xidx+1, yidx+1, zidx]
    c111 = volume[xidx+1, yidx+1, zidx+1]
    return [c000, c100, c010, c110, c001, c101, c110, c111]
end


function trilinear_interpolate(x::Float64, y::Float64, z::Float64, grid, volume)

    # Find the indices of the lower left corner of the cube we're inside of
    xs, ys, zs = grid.cutPoints
    xidx = findlast(xs .<= x)
    yidx = findlast(ys .<= y)
    zidx = findlast(zs .<= z)

    # Get the coordinate values of the lower left and upper right corners
    x0, y0, z0 = xs[xidx], ys[yidx], zs[zidx]
    x1, y1, z1 = xs[xidx+1], ys[yidx+1], zs[zidx+1]

    # Get the coordinate matrices
    Minv = make_inverse_coordinate_matrix(x0, y0, z0, x1, y1, z1)

    # Get the colors of the corners
    c = get_colors(volume, xidx, yidx, zidx)

    # Get the component vector
    p = [1; x; y; z; x * y; x * z; y * z; x * y * z]

    return p' * Minv * c
end
trilinear_interpolate(pt::Vec3{Float64}; grid, volume) = interpolate(pt.x, pt.y, pt.z, grid, volume)


function raytrace_trilinear(ray, spacing::Float64, grid, volume)
    pts = trace.(0:spacing:1; ray=ray)
    interpolations = interpolate.(pts; grid, volume)
    return sum(interpolations) / length(pts)
end


function make_drr(grid, volume, camera, detector, spacing)

    # Set up the detector plane
    plane = make_plane(detector)
    projector = get_rays(camera, plane)

    # Trace rays through the voxel grid
    drr = [raytrace_trilinear(ray, spacing, grid, volume) for ray in projector]
    return drr

end