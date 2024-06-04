# sage.doctest: needs sage.groups
r"""
Double cosets

This module implements a general algorithm for computing double coset problems
for pairs of objects. The class of objects in question must be some kind
of structure for which an isomorphism is a permutation in $S_n$ for some $n$,
which we call here the order of the object. Given objects $X$ and $Y$,
the program returns an isomorphism in list permutation form if $X \cong Y$, and
a NULL pointer otherwise.

In order to take advantage of the algorithms in this module for a specific kind
of object, one must implement (in Cython) three functions which will be specific
to the kind of objects in question. Pointers to these functions are passed to
the main function of the module, which is \code{double_coset}. For specific
examples of implementations of these functions, see any of the files in
\code{sage.groups.perm_gps.partn_ref} beginning with "refinement." They are:

A. \code{refine_and_return_invariant}:

    Signature:

    \code{int refine_and_return_invariant(PartitionStack *PS, void *S, int *cells_to_refine_by, int ctrb_len)}

    This function should split up cells in the partition at the top of the
    partition stack in such a way that any automorphism that respects the
    partition also respects the resulting partition. The array
    cells_to_refine_by is a list of the beginning positions of some cells which
    have been changed since the last refinement. It is not necessary to use
    this in an implementation of this function, but it will affect performance.
    One should consult \code{refinement_graphs} for more details and ideas for
    particular implementations.

    Output:

    An integer $I$ invariant under the orbits of $S_n$.  That is, if
    $\gamma \in S_n$, then
    $$ I(G, PS, cells_to_refine_by) = I( \gamma(G), \gamma(PS), \gamma(cells_to_refine_by) ) .$$


B. \code{compare_structures}:

    Signature:

    \code{int compare_structures(int *gamma_1, int *gamma_2, void *S1, void *S2, int degree)}

    This function must implement a total ordering on the set of objects of fixed
    order. Return:
        -1 if \code{gamma_1^{-1}(S1) < gamma_2^{-1}(S2)},
        0 if \code{gamma_1^{-1}(S1) == gamma_2^{-1}(S2)},
        1 if \code{gamma_1^{-1}(S1) > gamma_2^{-1}(S2)}.

    Important note:

    The permutations are thought of as being input in inverse form, and this can
    lead to subtle bugs. One is encouraged to consult existing implementations
    to make sure the right thing is being done: this is so that you can avoid
    *actually* needing to compute the inverse.

C. \code{all_children_are_equivalent}:

    Signature:

    \code{bint all_children_are_equivalent(PartitionStack *PS, void *S)}

    This function must return False unless it is the case that each discrete
    partition finer than the top of the partition stack is equivalent to the
    others under some automorphism of S. The converse need not hold: if this is
    indeed the case, it still may return False. This function is originally used
    as a consequence of Lemma 2.25 in [1].

EXAMPLES::

    sage: import sage.groups.perm_gps.partn_ref.double_coset

REFERENCE:

- [1] McKay, Brendan D. Practical Graph Isomorphism. Congressus Numerantium,
  Vol. 30 (1981), pp. 45-87.

- [2] Leon, Jeffrey. Permutation Group Algorithms Based on Partitions, I:
  Theory and Algorithms. J. Symbolic Computation, Vol. 12 (1991), pp.
  533-583.
"""

#*****************************************************************************
#       Copyright (C) 2006 - 2011 Robert L. Miller <rlmillster@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
#*****************************************************************************

from cysignals.memory cimport sig_calloc

from sage.groups.perm_gps.partn_ref.data_structures cimport *
from sage.data_structures.bitset_base cimport *

# Functions

cdef bint all_children_are_equivalent_trivial(PartitionStack *PS, void *S) noexcept:
    return 0

cdef int refine_and_return_invariant_trivial(PartitionStack *PS, void *S, int *cells_to_refine_by, int ctrb_len) noexcept:
    return 0

cdef int compare_perms(int *gamma_1, int *gamma_2, void *S1, void *S2, int degree) noexcept:
    cdef list MS1 = <list> S1
    cdef list MS2 = <list> S2
    cdef int i, j
    for i in range(degree):
        j = int_cmp(MS1[gamma_1[i]], MS2[gamma_2[i]])
        if j != 0:
            return j
    return 0

def coset_eq(list perm1=[0,1,2,3,4,5], list perm2=[1,2,3,4,5,0], list gens=[[1,2,3,4,5,0]]):
    """
    Given a group G generated by the given generators, tests whether the given
    permutations are in the same right coset of G. Tests nontrivial input group
    when using double_coset. If they are, return an element g so that
    g.perm1 = perm2 (composing left to right).

    TESTS::

        sage: from sage.groups.perm_gps.partn_ref.double_coset import coset_eq
        sage: coset_eq()
        [5, 0, 1, 2, 3, 4]
        sage: gens = [[1,2,3,0]]
        sage: reps = [[0,1,2,3]]
        sage: for p in SymmetricGroup(4):
        ....:   p = [p(i)-1 for i in range(1,5)]
        ....:   found = False
        ....:   for r in reps:
        ....:       if coset_eq(p, r, gens):
        ....:           found = True
        ....:           break
        ....:   if not found:
        ....:       reps.append(p)
        sage: len(reps)
        6
        sage: gens = [[1,0,2,3],[0,1,3,2]]
        sage: reps = [[0,1,2,3]]
        sage: for p in SymmetricGroup(4):
        ....:   p = [p(i)-1 for i in range(1,5)]
        ....:   found = False
        ....:   for r in reps:
        ....:       if coset_eq(p, r, gens):
        ....:           found = True
        ....:           break
        ....:   if not found:
        ....:       reps.append(p)
        sage: len(reps)
        6
        sage: gens = [[1,2,0,3]]
        sage: reps = [[0,1,2,3]]
        sage: for p in SymmetricGroup(4):
        ....:   p = [p(i)-1 for i in range(1,5)]
        ....:   found = False
        ....:   for r in reps:
        ....:       if coset_eq(p, r, gens):
        ....:           found = True
        ....:           break
        ....:   if not found:
        ....:       reps.append(p)
        sage: len(reps)
        8

    """
    cdef int i, n = len(perm1)
    assert all(len(g) == n for g in gens+[perm2])
    cdef PartitionStack *part = PS_new(n, 1)
    cdef int *c_perm = <int *> sig_malloc(n * sizeof(int))
    cdef StabilizerChain *group = SC_new(n, 1)
    cdef int *isomorphism = <int *> sig_malloc(n * sizeof(int))
    if part is NULL or c_perm is NULL or group is NULL or isomorphism is NULL:
        sig_free(c_perm)
        PS_dealloc(part)
        SC_dealloc(group)
        sig_free(isomorphism)
        raise MemoryError
    for g in gens:
        for i from 0 <= i < n:
            c_perm[i] = g[i]
        SC_insert(group, 0, c_perm, 1)
    for i from 0 <= i < n:
        c_perm[i] = i
    cdef bint isomorphic = double_coset(<void *> perm1, <void *> perm2, part, c_perm, n, &all_children_are_equivalent_trivial, &refine_and_return_invariant_trivial, &compare_perms, group, NULL, isomorphism)
    sig_free(c_perm)
    PS_dealloc(part)
    SC_dealloc(group)
    if isomorphic:
        x = [isomorphism[i] for i from 0 <= i < n]
    else:
        x = False
    sig_free(isomorphism)
    return x

cdef dc_work_space *allocate_dc_work_space(int n) noexcept:
    r"""
    Allocates work space for the double_coset function. It can be
    input to the function in which case it must be deallocated after the
    function is called.
    """
    cdef int *int_array

    cdef dc_work_space *work_space
    work_space = <dc_work_space *> sig_malloc(sizeof(dc_work_space))
    if work_space is NULL:
        return NULL

    work_space.degree = n
    int_array = <int *> sig_malloc((n*n + # for perm_stack
                                     5*n   # for int_array
                                    )*sizeof(int))
    work_space.group1 = SC_new(n)
    work_space.group2 = SC_new(n)
    work_space.current_ps = PS_new(n,0)
    work_space.first_ps   = PS_new(n,0)
    work_space.bitset_array = <bitset_t *> sig_calloc((n + 2*len_of_fp_and_mcr + 1), sizeof(bitset_t))
    work_space.orbits_of_subgroup = OP_new(n)
    work_space.perm_stack = NULL

    if int_array                        is NULL or \
       work_space.group1                is NULL or \
       work_space.group2                is NULL or \
       work_space.current_ps            is NULL or \
       work_space.first_ps              is NULL or \
       work_space.bitset_array          is NULL or \
       work_space.orbits_of_subgroup    is NULL:
        sig_free(int_array)
        deallocate_dc_work_space(work_space)
        return NULL

    work_space.perm_stack = int_array
    work_space.int_array  = int_array + n*n

    cdef int i
    for i from 0 <= i < n + 2*len_of_fp_and_mcr + 1:
        work_space.bitset_array[i].bits = NULL
    try:
        for i from 0 <= i < n + 2*len_of_fp_and_mcr + 1:
            bitset_init(work_space.bitset_array[i], n)
    except MemoryError:
        deallocate_dc_work_space(work_space)
        return NULL
    return work_space

cdef void deallocate_dc_work_space(dc_work_space *work_space) noexcept:
    r"""
    Deallocates work space for the double_coset function.
    """
    if work_space is NULL:
        return
    cdef int i, n = work_space.degree
    if work_space.bitset_array is not NULL:
        for i from 0 <= i < n + 2*len_of_fp_and_mcr + 1:
            bitset_free(work_space.bitset_array[i])
    sig_free(work_space.perm_stack)
    SC_dealloc(work_space.group1)
    SC_dealloc(work_space.group2)
    PS_dealloc(work_space.current_ps)
    PS_dealloc(work_space.first_ps)
    sig_free(work_space.bitset_array)
    OP_dealloc(work_space.orbits_of_subgroup)
    sig_free(work_space)

cdef int double_coset(void *S1, void *S2, PartitionStack *partition1, int *ordering2,
    int n, bint (*all_children_are_equivalent)(PartitionStack *PS, void *S) noexcept,
    int (*refine_and_return_invariant)(PartitionStack *PS, void *S,
                                       int *cells_to_refine_by, int ctrb_len) noexcept,
    int (*compare_structures)(int *gamma_1, int *gamma_2, void *S1, void *S2,
                              int degree) noexcept,
    StabilizerChain *input_group,
    dc_work_space *work_space_prealloc, int *isom) except -1:
    """
    Traverse the search space for double coset calculation.

    INPUT:
    S1, S2 -- pointers to the structures
    partition1 -- PartitionStack of depth 0 and degree n,
        whose first partition is of the points of S1
    ordering2 -- an ordering of the points of S2 representing a second partition
    n -- the number of points (points are assumed to be 0,1,...,n-1)
    all_children_are_equivalent -- pointer to a function
        INPUT:
        PS -- pointer to a partition stack
        S -- pointer to the structure
        OUTPUT:
        bint -- returns True if it can be determined that all refinements below
            the current one will result in an equivalent discrete partition
    refine_and_return_invariant -- pointer to a function
        INPUT:
        PS -- pointer to a partition stack
        S -- pointer to the structure
        alpha -- an array consisting of numbers, which indicate the starting
            positions of the cells to refine against (will likely be modified)
        OUTPUT:
        int -- returns an invariant under application of arbitrary permutations
    compare_structures -- pointer to a function
        INPUT:
        gamma_1, gamma_2 -- (list) permutations of the points of S1 and S2
        S1, S2 -- pointers to the structures
        degree -- degree of gamma_1 and 2
        OUTPUT:
        int -- 0 if gamma_1(S1) = gamma_2(S2), otherwise -1 or 1 (see docs for cmp),
            such that the set of all structures is well-ordered
    input_group -- either a specified group to limit the search to,
        or NULL for the full symmetric group
    isom -- space to store the isomorphism to,
        or NULL if isomorphism is not needed

    .. NOTE::

        The partition ``partition1`` and the resulting partition from
        ``ordering2`` *must* satisfy the property that in each cell, the
        smallest element occurs first!

    OUTPUT: ``1`` if ``S1`` and ``S2`` are isomorphic, otherwise ``0``
    """
    cdef PartitionStack *current_ps
    cdef PartitionStack *first_ps
    cdef PartitionStack *left_ps
    cdef int first_meets_current = -1
    cdef int current_kids_are_same = 1
    cdef int first_kids_are_same

    cdef int *indicators

    cdef OrbitPartition *orbits_of_subgroup
    cdef OrbitPartition *orbits_of_supergroup
    cdef int subgroup_primary_orbit_size = 0
    cdef int minimal_in_primary_orbit

    cdef bitset_t *fixed_points_of_generators # i.e. fp
    cdef bitset_t *minimal_cell_reps_of_generators # i.e. mcr
    cdef int len_of_fp_and_mcr = 100
    cdef int index_in_fp_and_mcr = -1

    cdef bitset_t *vertices_to_split
    cdef bitset_t *vertices_have_been_reduced
    cdef int *permutation
    cdef int *id_perm
    cdef int *cells_to_refine_by
    cdef int *vertices_determining_current_stack
    cdef int *perm_stack
    cdef StabilizerChain *group
    cdef StabilizerChain *old_group
    cdef StabilizerChain *tmp_gp

    cdef int i, j, k, ell, b
    cdef bint automorphism
    cdef bint new_vertex, mem_err = 0

    if n == 0:
        return 0

    if work_space_prealloc is not NULL:
        work_space = work_space_prealloc
    else:
        work_space = allocate_dc_work_space(n)
        if work_space is NULL:
            raise MemoryError

    # Allocate:
    if input_group is not NULL:
        perm_stack                     = work_space.perm_stack
        group                          = work_space.group1
        old_group                      = work_space.group2
        orbits_of_supergroup           = input_group.OP_scratch
        SC_copy_nomalloc(group, input_group, n)
        SC_identify(perm_stack, n)

    current_ps                         = work_space.current_ps
    first_ps                           = work_space.first_ps
    orbits_of_subgroup                 = work_space.orbits_of_subgroup

    indicators                         = work_space.int_array
    permutation                        = work_space.int_array +   n
    id_perm                            = work_space.int_array + 2*n
    cells_to_refine_by                 = work_space.int_array + 3*n
    vertices_determining_current_stack = work_space.int_array + 4*n

    fixed_points_of_generators         = work_space.bitset_array
    minimal_cell_reps_of_generators    = work_space.bitset_array + len_of_fp_and_mcr
    vertices_to_split                  = work_space.bitset_array + 2*len_of_fp_and_mcr
    vertices_have_been_reduced         = work_space.bitset_array + 2*len_of_fp_and_mcr + n

    if work_space_prealloc is not NULL:
        OP_clear(orbits_of_subgroup)

    bitset_zero(vertices_have_been_reduced[0])
    left_ps = partition1

    cdef bint possible = 1
    cdef bint unknown = 1

    # set up the identity permutation
    for i in range(n):
        id_perm[i] = i
    if ordering2 is NULL:
        ordering2 = id_perm

    # Copy reordering of left_ps coming from ordering2 to current_ps.
    memcpy(current_ps.entries, ordering2, n * sizeof(int))
    memcpy(current_ps.levels, left_ps.levels, n * sizeof(int))
    current_ps.depth = left_ps.depth

    # default values of "infinity"
    for i from 0 <= i < n:
        indicators[i] = -1

    # Our first refinement needs to check every cell of the partition,
    # so cells_to_refine_by needs to be a list of pointers to each cell.
    j = 1
    cells_to_refine_by[0] = 0
    for i from 0 < i < n:
        if left_ps.levels[i-1] == 0:
            cells_to_refine_by[j] = i
            j += 1
    if input_group is NULL:
        k = refine_and_return_invariant(left_ps, S1, cells_to_refine_by, j)
    else:
        k = refine_also_by_orbits(left_ps, S1, refine_and_return_invariant,
            cells_to_refine_by, j, group, perm_stack)
    j = 1
    cells_to_refine_by[0] = 0
    for i from 0 < i < n:
        if current_ps.levels[i-1] == 0:
            cells_to_refine_by[j] = i
            j += 1
    if input_group is NULL:
        j = refine_and_return_invariant(current_ps, S2, cells_to_refine_by, j)
    else:
        j = refine_also_by_orbits(current_ps, S2, refine_and_return_invariant,
            cells_to_refine_by, j, group, perm_stack)
    if k != j:
        possible = 0
        unknown = 0
    elif not stacks_are_equivalent(left_ps, current_ps):
        possible = 0
        unknown = 0
    else:
        PS_move_all_mins_to_front(current_ps)

    # Refine down to a discrete partition
    while not PS_is_discrete(left_ps):
        i = left_ps.depth
        k = PS_first_smallest(left_ps, vertices_to_split[i]) # writes to vertices_to_split, but this is never used
        if input_group is not NULL:
            OP_clear(orbits_of_supergroup)
            for j from i <= j < group.base_size:
                for ell from 0 <= ell < group.num_gens[j]:
                    OP_merge_list_perm(orbits_of_supergroup, group.generators[j] + n*ell)
            b = orbits_of_supergroup.mcr[OP_find(orbits_of_supergroup, perm_stack[i*n + k])]
            tmp_gp = group
            group = old_group
            old_group = tmp_gp
            if SC_insert_base_point_nomalloc(group, old_group, i, b):
                mem_err = 1
                break
            indicators[i] = split_point_and_refine_by_orbits(left_ps, k, S1, refine_and_return_invariant, cells_to_refine_by, group, perm_stack)
        else:
            indicators[i] = split_point_and_refine(left_ps, k, S1, refine_and_return_invariant, cells_to_refine_by)
        bitset_unset(vertices_have_been_reduced[0], left_ps.depth)

    if not mem_err:
        while not PS_is_discrete(current_ps) and possible:
            i = current_ps.depth
            vertices_determining_current_stack[i] = PS_first_smallest(current_ps, vertices_to_split[i])
            if input_group is not NULL:
                if group.parents[i][perm_stack[n*i + vertices_determining_current_stack[i]]] == -1:
                    possible = 0
            while possible:
                i = current_ps.depth
                if input_group is not NULL:
                    j = split_point_and_refine_by_orbits(current_ps, vertices_determining_current_stack[i],
                        S2, refine_and_return_invariant, cells_to_refine_by, group, perm_stack)
                else:
                    j = split_point_and_refine(current_ps,
                        vertices_determining_current_stack[i], S2,
                        refine_and_return_invariant, cells_to_refine_by)
                if indicators[i] != j:
                    possible = 0
                elif not stacks_are_equivalent(left_ps, current_ps):
                    possible = 0
                else:
                    PS_move_all_mins_to_front(current_ps)
                    if not all_children_are_equivalent(current_ps, S2):
                        current_kids_are_same = current_ps.depth + 1
                    break
                current_ps.depth -= 1
                while current_ps.depth >= 0: # not possible, so look for another
                    i = current_ps.depth
                    j = vertices_determining_current_stack[i] + 1
                    j = bitset_next(vertices_to_split[i], j)
                    if j == -1:
                        current_ps.depth -= 1 # backtrack
                    else:
                        possible = 1
                        vertices_determining_current_stack[i] = j
                        break # found another
        if possible:
            if input_group is NULL:
                if compare_structures(left_ps.entries, current_ps.entries, S1, S2, n) == 0:
                    unknown = 0
            else:
                PS_get_perm_from(left_ps, current_ps, permutation)
                if SC_contains(group, 0, permutation, 0) and compare_structures(permutation, id_perm, S1, S2, n) == 0:
                    # TODO: might be slight optimization for containment using perm_stack
                    unknown = 0
            if unknown:
                first_meets_current = current_ps.depth
                first_kids_are_same = current_ps.depth
                PS_copy_from_to(current_ps, first_ps)
                current_ps.depth -= 1

    if mem_err:
        if work_space_prealloc is NULL:
            deallocate_dc_work_space(work_space)
        raise MemoryError

    # Main loop:
    while possible and unknown and current_ps.depth != -1:

        # I. Search for a new vertex to split, and update subgroup information
        new_vertex = 0
        if current_ps.depth > first_meets_current:
            # If we are not at a node of the first stack, reduce size of
            # vertices_to_split by using the symmetries we already know.
            if not bitset_check(vertices_have_been_reduced[0], current_ps.depth):
                for i from 0 <= i <= index_in_fp_and_mcr:
                    j = 0
                    while j < current_ps.depth and bitset_check(fixed_points_of_generators[i], vertices_determining_current_stack[j]):
                        j += 1
                    # If each vertex split so far is fixed by generator i,
                    # then remove elements of vertices_to_split which are
                    # not minimal in their orbits under generator i.
                    if j == current_ps.depth:
                        for k from 0 <= k < n:
                            if bitset_check(vertices_to_split[current_ps.depth], k) and not bitset_check(minimal_cell_reps_of_generators[i], k):
                                bitset_flip(vertices_to_split[current_ps.depth], k)
                bitset_flip(vertices_have_been_reduced[0], current_ps.depth)
            # Look for a new point to split.
            i = vertices_determining_current_stack[current_ps.depth] + 1
            i = bitset_next(vertices_to_split[current_ps.depth], i)
            if i != -1:
                # There is a new point.
                vertices_determining_current_stack[current_ps.depth] = i
                new_vertex = 1
            else:
                # No new point: backtrack.
                current_ps.depth -= 1
        else:
            # If we are at a node of the first stack, the above reduction
            # will not help. Also, we must update information about
            # primary orbits here.
            if current_ps.depth < first_meets_current:
                # If we are done searching under this part of the first
                # stack, then first_meets_current is one higher, and we
                # are looking at a new primary orbit (corresponding to a
                # larger subgroup in the stabilizer chain).
                first_meets_current = current_ps.depth
                for i from 0 <= i < n:
                    if bitset_check(vertices_to_split[current_ps.depth], i):
                        minimal_in_primary_orbit = i
                        break
            while True:
                i = vertices_determining_current_stack[current_ps.depth]
                # This was the last point to be split here.
                # If it is in the same orbit as minimal_in_primary_orbit,
                # then count it as an element of the primary orbit.
                if OP_find(orbits_of_subgroup, i) == OP_find(orbits_of_subgroup, minimal_in_primary_orbit):
                    subgroup_primary_orbit_size += 1
                # Look for a new point to split.
                i += 1
                i = bitset_next(vertices_to_split[current_ps.depth], i)
                if i != -1:
                    # There is a new point.
                    vertices_determining_current_stack[current_ps.depth] = i
                    if orbits_of_subgroup.mcr[OP_find(orbits_of_subgroup, i)] == i:
                        new_vertex = 1
                        break
                else:
                    # No new point: backtrack.
                    # Note that now, we are backtracking up the first stack.
                    vertices_determining_current_stack[current_ps.depth] = -1
                    # If every choice of point to split gave something in the
                    # (same!) primary orbit, then all children of the first
                    # stack at this point are equivalent.
                    j = 0
                    for i in range(n):
                        if bitset_check(vertices_to_split[current_ps.depth], i):
                            j += 1
                    if j == subgroup_primary_orbit_size and first_kids_are_same == current_ps.depth+1:
                        first_kids_are_same = current_ps.depth
                    # Backtrack.
                    subgroup_primary_orbit_size = 0
                    current_ps.depth -= 1
                    break
        if not new_vertex:
            continue

        if current_kids_are_same > current_ps.depth + 1:
            current_kids_are_same = current_ps.depth + 1

        # II. Refine down to a discrete partition, or until
        # we leave the part of the tree we are interested in
        while True:
            i = current_ps.depth
            while True:
                if input_group is not NULL:
                    k = split_point_and_refine_by_orbits(current_ps,
                        vertices_determining_current_stack[i], S2,
                        refine_and_return_invariant, cells_to_refine_by,
                        group, perm_stack)
                    update_perm_stack(group, current_ps.depth, vertices_determining_current_stack[i], perm_stack)
                else:
                    k = split_point_and_refine(current_ps,
                        vertices_determining_current_stack[i], S2,
                        refine_and_return_invariant, cells_to_refine_by)
                PS_move_all_mins_to_front(current_ps)
                if indicators[i] != k:
                    possible = 0
                elif not stacks_are_equivalent(left_ps, current_ps):
                    possible = 0
                if PS_is_discrete(current_ps):
                    break
                vertices_determining_current_stack[current_ps.depth] = PS_first_smallest(current_ps, vertices_to_split[current_ps.depth])
                if input_group is not NULL:
                    if group.parents[current_ps.depth][perm_stack[n*current_ps.depth + vertices_determining_current_stack[current_ps.depth]]] == -1:
                        possible = 0
                if not possible:
                    j = vertices_determining_current_stack[i] + 1
                    j = bitset_next(vertices_to_split[i], j)
                    if j == -1:
                        break
                    else:
                        possible = 1
                        vertices_determining_current_stack[i] = j
                        current_ps.depth -= 1 # reset for next refinement
                else:
                    break
            if not possible:
                break
            if PS_is_discrete(current_ps):
                break
            bitset_unset(vertices_have_been_reduced[0], current_ps.depth)
            if not all_children_are_equivalent(current_ps, S2):
                current_kids_are_same = current_ps.depth + 1

        # III. Check for automorphisms and isomorphisms
        automorphism = 0
        if possible:
            PS_get_perm_from(first_ps, current_ps, permutation)
            if compare_structures(permutation, id_perm, S2, S2, n) == 0:
                if input_group is NULL or SC_contains(group, 0, permutation, 0):
                    # TODO: might be slight optimization for containment using perm_stack
                    automorphism = 1
        if not automorphism and possible:
            # if we get here, discrete must be true
            if current_ps.depth != left_ps.depth:
                possible = 0
            elif input_group is NULL:
                if compare_structures(left_ps.entries, current_ps.entries, S1, S2, n) == 0:
                    unknown = 0
                    break
                else:
                    possible = 0
            else:
                PS_get_perm_from(left_ps, current_ps, permutation)
                if SC_contains(group, 0, permutation, 0) and compare_structures(permutation, id_perm, S1, S2, n) == 0:
                    # TODO: might be slight optimization for containment using perm_stack
                    unknown = 0
                    break
                else:
                    possible = 0
        if automorphism:
            if index_in_fp_and_mcr < len_of_fp_and_mcr - 1:
                index_in_fp_and_mcr += 1
            bitset_zero(fixed_points_of_generators[index_in_fp_and_mcr])
            bitset_zero(minimal_cell_reps_of_generators[index_in_fp_and_mcr])
            for i in range(n):
                if permutation[i] == i:
                    bitset_set(fixed_points_of_generators[index_in_fp_and_mcr], i)
                    bitset_set(minimal_cell_reps_of_generators[index_in_fp_and_mcr], i)
                else:
                    bitset_unset(fixed_points_of_generators[index_in_fp_and_mcr], i)
                    k = i
                    j = permutation[i]
                    while j != i:
                        if j < k:
                            k = j
                        j = permutation[j]
                    if k == i:
                        bitset_set(minimal_cell_reps_of_generators[index_in_fp_and_mcr], i)
                    else:
                        bitset_unset(minimal_cell_reps_of_generators[index_in_fp_and_mcr], i)
            current_ps.depth = first_meets_current
            if OP_merge_list_perm(orbits_of_subgroup, permutation): # if permutation made orbits coarser
                if orbits_of_subgroup.mcr[OP_find(orbits_of_subgroup, minimal_in_primary_orbit)] != minimal_in_primary_orbit:
                    continue # main loop
            if bitset_check(vertices_have_been_reduced[0], current_ps.depth):
                bitset_and(vertices_to_split[current_ps.depth], vertices_to_split[current_ps.depth], minimal_cell_reps_of_generators[index_in_fp_and_mcr])
            continue # main loop
        if not possible:
            possible = 1
            i = current_ps.depth
            current_ps.depth = current_kids_are_same-1
            if i == current_kids_are_same:
                continue # main loop
            if index_in_fp_and_mcr < len_of_fp_and_mcr - 1:
                index_in_fp_and_mcr += 1
            bitset_zero(fixed_points_of_generators[index_in_fp_and_mcr])
            bitset_zero(minimal_cell_reps_of_generators[index_in_fp_and_mcr])
            j = current_ps.depth
            current_ps.depth = i # just for mcr and fixed functions...
            for i from 0 <= i < n:
                if PS_is_mcr(current_ps, i):
                    bitset_set(minimal_cell_reps_of_generators[index_in_fp_and_mcr], i)
                    if PS_is_fixed(current_ps, i):
                        bitset_set(fixed_points_of_generators[index_in_fp_and_mcr], i)
            current_ps.depth = j
            if bitset_check(vertices_have_been_reduced[0], current_ps.depth):
                bitset_and(vertices_to_split[current_ps.depth], vertices_to_split[current_ps.depth], minimal_cell_reps_of_generators[index_in_fp_and_mcr])

    # End of main loop.
    if possible and not unknown and isom is not NULL:
        for i from 0 <= i < n:
            isom[left_ps.entries[i]] = current_ps.entries[i]

    # Deallocate:
    if work_space_prealloc is NULL:
        deallocate_dc_work_space(work_space)
    return 1 if (possible and not unknown) else 0
