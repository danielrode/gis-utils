

# Concurrency
# Must start with `julia --threads n` (where n is greater than 1)
using Base.Threads: @threads as @go

@go for i in (1,2,3) sleep(i) end


# GDAL
using GDAL
# https://github.com/JuliaGeo/GDAL.jl/blob/master/test/tutorial_vector.jl


# Piping
[1,2,1,5] |> sum
