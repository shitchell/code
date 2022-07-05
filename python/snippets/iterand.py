from typing import Iterable

def iterand(a: Iterable, b: Iterable, keep_missing: bool = False) -> list:
  """
  Returns every value in `a` where `b` has a corresponding truthy value
  """
  
  if keep_missing:
    alen = len(a)
    blen = len(b)
    if alen > blen:
      b.extend([1] * (alen - blen))
    
  return [ax for (ax, bx) in zip(a, b) if bx]
