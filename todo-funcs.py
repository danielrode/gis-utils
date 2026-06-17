

# TODO add these functions to library





def preview_tifs(tif_dir, dst_pdf):
    """Generate PDF preview of a given TIF."""

    # Ensure paths don't contain NULL character(s) (R can't handle these)
    for path in (tif_dir, dst_pdf):
        if '\0' in str(tif_dir):
            raise Exception("Path contains NULL: " + str(path))

    # Package data to send to R process
    ipc_data = {
        'tif_dir': str(tif_dir),
        'dst_pdf': str(dst_pdf),
    }
    ipc = json.dumps(
        ipc_data,
        allow_nan=False,
        ensure_ascii=True,
        separators=(',', ':'),
        indent=None,
    )

    # Run R code
    r_code = r"""
    library(terra)
    library(jsonlite)

    ipc = jsonlite::fromJSON(readLines(file("stdin")))

    tif_dir = file.path(ipc$tif_dir)
    out_path = file.path(ipc$dst_pdf)

    # Compile list of rasters to generate previews for
    tif_list = list.files(tif_dir, pattern="\\.tif$", full.names=TRUE)

    # Generate and save PDF previews
    pdf(out_path, onefile=TRUE)
    for (tif_path in tif_list) {{
        # Load raster
        r = terra::rast(tif_path)

        # Plot each layer of each raster
        for (i in seq_len(nlyr(r))) {{
            plot(r[[i]], main=paste(basename(tif_path), "-", names(r)[i]))
        }}
    }}
    dev.off()
    """
    cmd = ('R', '--vanilla', '-e', r_code)
    sp.run(cmd, check=True, text=True, input=ipc.strip())





from typing import Literal
from matplotlib.axes import Axes

def plot_sat(
    ax: Axes,
    aoi: GeoDataFrame,
    zoom: int|Literal['auto']='auto',
    provider = "ESRI",
) -> Axes:
    """Plot satellite imagery (from ESRI) on the given canvas.

    tags: google, earth
    """

    import contextily as cx
    import xyzservices.providers as xyz

    match provider:
        case "ESRI":
            xyz_provider = xyz.Esri.WorldImagery
        case _:
            raise Exception(f"Unknown provider {provider}")

    # Set axis extent
    ax.plot(
        *aoi.union_all().exterior.xy,
        label="Plot Edge",
        alpha=0.0,  # Hide
        color='black',
    )

    # Plot sat imagery
    cx.add_basemap(
        ax=ax,
        crs=aoi.crs,
        source=xyz_provider,
        zoom=zoom,
        attribution="",  # Hide attribution text
    )



