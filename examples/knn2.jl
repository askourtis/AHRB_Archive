using AdaptiveHierarchicalRegularBinning
using AbstractTrees

# Setup
n = 100000
d = 2
dims = 2

dpt = 4
sml = 1000

X = randn(n, d)

if dims == 2
  X = X |> transpose |> collect
end

tree = regular_bin(UInt128, X, dpt, sml; dims=dims)

# Callbacks
function leaf_cb(leaf)
  setcontext!(leaf, extrema(points(leaf); dims=leaddim(leaf))[:])
end

function node_cb(node)
  r = [ (Inf, -Inf) for _ in 1:bitlen(node) ]

  for child in children(node)
    ctx = getcontext(child)
    for (d, (m, M)) in enumerate(ctx)
      r[d] = (min(r[d][1], m), max(r[d][2], M))
    end
  end

  setcontext!(node, r)
end

# Evaluate
# Tree context -> Vector of size d, each element is a tuple of (min, max) per dim
applypostorder!(tree, leaf_cb, node_cb)

map(x -> x[1], getcontext(tree)) .- minimum(points(tree), dims=dims)

## redo with built-in AbstractTrees functions, I am learning!
function tightbox(node)
  if isleaf(node)
    setcontext!(node, extrema(points(node); dims=leaddim(node))[:])
  else
    bound(acc, ctx) = [ (min(a[1], c[1]), max(a[2], c[2])) for (a, c) in zip(acc,ctx) ]
    children(node) |>
      (C) -> mapreduce(getcontext, bound, C) |>
      (R) -> setcontext!(node, R)
  end
end

foreach(tightbox, PostOrderDFS(tree))

map(x -> x[1], getcontext(tree)) .- minimum(points(tree), dims=dims)