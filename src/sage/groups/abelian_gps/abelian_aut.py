r"""
Automorphisms of abelian groups

This implements groups of automorphisms of abelian groups.

EXAMPLES::

    sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
    sage: G = AbelianGroupGap([2,6])
    sage: autG = G.aut()

Automorphisms act on the elements of the domain::

    sage: g = G.an_element()
    sage: f = autG.an_element()
    sage: f
    Pcgs([ f1, f2, f3 ]) -> [ f1, f1*f2*f3^2, f3^2 ]
    sage: (g, f(g))
    (f1*f2, f2*f3^2)

Or anything coercible into its domain::

    sage: A = AbelianGroup([2,6])
    sage: a = A.an_element()
    sage: (a, f(a))
    (f0*f1, f2*f3^2)
    sage: A = AdditiveAbelianGroup([2,6])
    sage: a = A.an_element()
    sage: (a, f(a))
    ((1, 0), f1)
    sage: f((1,1))
    f2*f3^2

We can compute conjugacy classes::

    sage: autG.conjugacy_classes_representatives()
    (1,
     Pcgs([ f1, f2, f3 ]) -> [ f2*f3, f1*f2, f3 ],
     Pcgs([ f1, f2, f3 ]) -> [ f1*f2*f3, f2*f3^2, f3^2 ],
     [ f3^2, f1*f2*f3, f1 ] -> [ f3^2, f1, f1*f2*f3 ],
     Pcgs([ f1, f2, f3 ]) -> [ f2*f3, f1*f2*f3^2, f3^2 ],
     [ f1*f2*f3, f1, f3^2 ] -> [ f1*f2*f3, f1, f3 ])

the group order::

    sage: autG.order()
    12

or create subgroups and do the same for them::

    sage: S = autG.subgroup(autG.gens()[:1])
    sage: S
    Subgroup of automorphisms of Abelian group with gap, generator orders (2, 6)
    generated by 1 automorphisms

Only automorphism groups of finite abelian groups are supported::

    sage: G = AbelianGroupGap([0,2])        # optional - gap_package_polycyclic
    sage: autG = G.aut()                    # optional - gap_package_polycyclic
    Traceback (most recent call last):
    ...
    ValueError: only finite abelian groups are supported

AUTHORS:

- Simon Brandhorst (2018-02-17): initial version
"""

# ****************************************************************************
#       Copyright (C) 2018 Simon Brandhorst <sbrandhorst@web.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  https://www.gnu.org/licenses/
# ****************************************************************************
from sage.categories.groups import Groups
from sage.groups.abelian_gps.abelian_group_gap import AbelianGroup_gap
from sage.groups.group import Group
from sage.groups.libgap_wrapper import ParentLibGAP, ElementLibGAP
from sage.groups.libgap_mixin import GroupMixinLibGAP
from sage.libs.gap.libgap import libgap
from sage.matrix.matrix_space import MatrixSpace
from sage.rings.integer_ring import ZZ
from sage.structure.unique_representation import CachedRepresentation


class AbelianGroupAutomorphism(ElementLibGAP):
    """
    Automorphisms of abelian groups with gap.

    INPUT:

    - ``x`` -- a libgap element
    - ``parent`` -- the parent :class:`~AbelianGroupAutomorphismGroup_gap`
    - ``check`` -- boolean (default: ``True``); checks if ``x`` is an element
      of the group

    EXAMPLES::

        sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
        sage: G = AbelianGroupGap([2,3,4,5])
        sage: f = G.aut().an_element()
    """
    def __init__(self, parent, x, check=True):
        """
        The Python constructor.

        TESTS::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: f = G.aut().an_element()
            sage: TestSuite(f).run()
        """
        if check:
            if x not in parent.gap():
                raise ValueError("%s is not in the group %s" % (x, parent))
        ElementLibGAP.__init__(self, parent, x)

    def __hash__(self):
        r"""
        The hash of this element.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: f = G.aut().an_element()
            sage: f.__hash__() == hash(f.matrix())
            True
        """
        return hash(self.matrix())

    def __reduce__(self):
        """
        Implement pickling.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: f = G.aut().an_element()
            sage: f == loads(dumps(f))
            True
        """
        return (self.parent(), (self.matrix(),))

    def __call__(self, a):
        r"""
        Return the image of ``a`` under this automorphism.

        INPUT:

        - ``a`` -- something convertible into the domain

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4])
            sage: f = G.aut().an_element()
            sage: f
            Pcgs([ f1, f2, f3, f4 ]) -> [ f1*f4, f2^2, f1*f3, f4 ]
        """
        g = self.gap().ImageElm
        dom = self.parent()._domain
        a = dom(a)
        a = a.gap()
        return dom(g(a))

    def matrix(self):
        r"""
        Return the matrix defining ``self``.

        The `i`-th row is the exponent vector of
        the image of the `i`-th generator.

        OUTPUT: a square matrix over the integers

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4])
            sage: f = G.aut().an_element()
            sage: f
            Pcgs([ f1, f2, f3, f4 ]) -> [ f1*f4, f2^2, f1*f3, f4 ]
            sage: f.matrix()
            [1 0 2]
            [0 2 0]
            [1 0 1]

        Compare with the exponents of the images::

            sage: f(G.gens()[0]).exponents()
            (1, 0, 2)
            sage: f(G.gens()[1]).exponents()
            (0, 2, 0)
            sage: f(G.gens()[2]).exponents()
            (1, 0, 1)
        """
        R = self.parent()._covering_matrix_ring
        coeffs = [self(a).exponents() for a in self.parent()._domain.gens()]
        m = R(coeffs)
        m.set_immutable()
        return m

class AbelianGroupAutomorphismGroup_gap(CachedRepresentation,
                                        GroupMixinLibGAP,
                                        Group,
                                        ParentLibGAP):
    r"""
    Base class for groups of automorphisms of abelian groups.

    Do not construct this directly.

     INPUT:

    - ``domain`` -- :class:`~sage.groups.abelian_gps.abelian_group_gap.AbelianGroup_gap`
    - ``libgap_parent`` -- the libgap element that is the parent in GAP
    - ``category`` -- a category
    - ``ambient`` -- an instance of a derived class of
      :class:`~sage.groups.libgap_wrapper.ParentLibGAP` or ``None`` (default);
      the ambient group if ``libgap_parent`` has been defined as a subgroup

    EXAMPLES::

        sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
        sage: from sage.groups.abelian_gps.abelian_aut import AbelianGroupAutomorphismGroup_gap
        sage: domain = AbelianGroupGap([2,3,4,5])
        sage: aut = domain.gap().AutomorphismGroupAbelianGroup()
        sage: AbelianGroupAutomorphismGroup_gap(domain, aut, Groups().Finite())
        <group with 6 generators>
    """
    Element = AbelianGroupAutomorphism

    def __init__(self, domain, gap_group, category, ambient=None):
        """
        Constructor.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: G.aut()
            Full group of automorphisms of Abelian group with gap, generator orders (2, 3, 4, 5)
        """
        self._domain = domain
        n = len(self._domain.gens())
        self._covering_matrix_ring = MatrixSpace(ZZ, n)
        ParentLibGAP.__init__(self, gap_group, ambient=ambient)
        Group.__init__(self, category=category)

    def _element_constructor_(self, x, check=True):
        r"""
        Construct an element from ``x`` and handle conversions.

        INPUT:

        - ``x`` -- something that converts in can be:

          * a libgap element
          * an integer matrix in the covering matrix ring
          * a :class:`sage.modules.fg_pid.fgp_morphism.FGP_Morphism`
            defining an automorphism -- the domain of ``x`` must have
            invariants equal to ``self.domain().gens_orders()``

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.aut()
            sage: f = aut.an_element()
            sage: f == aut(f.matrix())
            True
            sage: G = AbelianGroupGap([2,10])
            sage: aut = G.aut()
            sage: D = ZZ^2/(ZZ^2).submodule([[10,0],[0,2]])
            sage: f = D.hom([D.0 + 5*D.1, 3*D.1])
            sage: f
            Morphism from module over Integer Ring with invariants (2, 10) to
             module with invariants (2, 10) that sends the generators to [(1, 5), (0, 3)]
            sage: aut(f)
            [ f1, f2 ] -> [ f1*f2*f3^2, f2*f3 ]
        """
        if x in self._covering_matrix_ring:
            dom = self._domain
            images = [dom(row).gap() for row in x.rows()]
            x = dom.gap().GroupHomomorphismByImages(dom.gap(), images)
        from sage.modules.fg_pid.fgp_morphism import FGP_Morphism
        if isinstance(x, FGP_Morphism):
            if x.base_ring() != ZZ:
                raise ValueError("base ring must be ZZ")
            # generators of fgp_modules are not assumed to be unique
            # thus we can only use smith_form_gens reliably.
            # Also conversions between the domains use the smith gens.
            if x.domain().invariants() != self.domain().gens_orders():
                raise ValueError("invariants of domains must agree")
            if not x.domain() == x.codomain():
                raise ValueError("domain and codomain do not agree")
            if not x.kernel().invariants() == ():
                raise ValueError("not an automorphism")
            dom = self._domain
            images = [dom(x(a)).gap() for a in x.domain().smith_form_gens()]
            x = dom.gap().GroupHomomorphismByImages(dom.gap(), images)
        return self.element_class(self, x, check)

    def _coerce_map_from_(self, S):
        r"""
        Return whether ``S`` coerces to ``self``.

        INPUT:

        - ``S`` -- anything

        OUTPUT: boolean or nothing

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: gen = G.gens()[:2]
            sage: S = G.subgroup(gen)
            sage: G._coerce_map_from_(S)
            True
            sage: S._coerce_map_from_(G)
            False
            sage: G._coerce_map_from_(ZZ) is None
            True
        """
        if isinstance(S, AbelianGroupAutomorphismGroup_gap):
            return S.is_subgroup_of(self)
        return super()._coerce_map_from_(S)

    def _subgroup_constructor(self, libgap_subgroup):
        r"""
        Create a subgroup from the input.

        See :class:`~sage.groups.libgap_wrapper`. Override this in derived
        classes.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: domain = AbelianGroupGap([2,3,4,5])
            sage: aut = domain.aut()
            sage: aut._subgroup_constructor(aut.gap())
            Subgroup of automorphisms of Abelian group with gap, generator orders (2, 3, 4, 5)
            generated by 6 automorphisms
        """
        ambient = self.ambient()
        generators = libgap_subgroup.GeneratorsOfGroup()
        generators = tuple([ambient(g) for g in generators])
        return AbelianGroupAutomorphismGroup_subgroup(ambient, generators)

    def covering_matrix_ring(self):
        r"""
        Return the covering matrix ring of this group.

        This is the ring of `n \times n` matrices over `\ZZ` where
        `n` is the number of (independent) generators.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.aut()
            sage: aut.covering_matrix_ring()
            Full MatrixSpace of 4 by 4 dense matrices over Integer Ring
        """
        return self._covering_matrix_ring

    def domain(self):
        r"""
        Return the domain of this group of automorphisms.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.aut()
            sage: aut.domain()
            Abelian group with gap, generator orders (2, 3, 4, 5)
        """
        return self._domain

    def is_subgroup_of(self, G):
        r"""
        Return if ``self`` is a subgroup of ``G`` considered in the same ambient group.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.aut()
            sage: gen = aut.gens()
            sage: S1 = aut.subgroup(gen[:2])
            sage: S1.is_subgroup_of(aut)
            True
            sage: S2 = aut.subgroup(aut.gens()[1:])
            sage: S2.is_subgroup_of(S1)
            False
        """
        if not isinstance(G, AbelianGroupAutomorphismGroup_gap):
            raise ValueError("input must be an instance of AbelianGroup_gap")
        if not self.ambient() is G.ambient():
            return False
        return G.gap().IsSubsemigroup(self).sage()

class AbelianGroupAutomorphismGroup(AbelianGroupAutomorphismGroup_gap):
    r"""
    The full automorphism group of a finite abelian group.

    INPUT:

    - ``AbelianGroupGap`` -- an instance of
      :class:`~sage.groups.abelian_gps.abelian_group_gap.AbelianGroup_gap`

    EXAMPLES::

        sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
        sage: from sage.groups.abelian_gps.abelian_aut import AbelianGroupAutomorphismGroup
        sage: G = AbelianGroupGap([2,3,4,5])
        sage: aut = G.aut()

    Equivalently::

        sage: aut1 = AbelianGroupAutomorphismGroup(G)
        sage: aut is aut1
        True
    """
    Element = AbelianGroupAutomorphism

    def __init__(self, AbelianGroupGap):
        """
        Constructor.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.aut()
            sage: TestSuite(aut).run()
        """
        self._domain = AbelianGroupGap
        if not isinstance(AbelianGroupGap, AbelianGroup_gap):
            raise ValueError("not an abelian group with GAP backend")
        if not self._domain.is_finite():
            raise ValueError("only finite abelian groups are supported")
        category = Groups().Finite().Enumerated()
        G = libgap.AutomorphismGroup(self._domain.gap())
        AbelianGroupAutomorphismGroup_gap.__init__(self,
                                                   self._domain,
                                                   gap_group=G,
                                                   category=category,
                                                   ambient=None)

    def _repr_(self):
        r"""
        String representation of ``self``.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.automorphism_group()
        """
        return "Full group of automorphisms of %s" % self.domain()

class AbelianGroupAutomorphismGroup_subgroup(AbelianGroupAutomorphismGroup_gap):
    r"""
    Groups of automorphisms of abelian groups.

    They are subgroups of the full automorphism group.

    .. NOTE::

        Do not construct this class directly; instead use
        :meth:`sage.groups.abelian_gps.abelian_group_gap.AbelianGroup_gap.subgroup`.

    INPUT:

    - ``ambient`` -- the ambient group
    - ``generators`` -- tuple of gap elements of the ambient group

    EXAMPLES::

        sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
        sage: from sage.groups.abelian_gps.abelian_aut import AbelianGroupAutomorphismGroup_subgroup
        sage: G = AbelianGroupGap([2,3,4,5])
        sage: aut = G.aut()
        sage: gen = aut.gens()
        sage: AbelianGroupAutomorphismGroup_subgroup(aut, gen)
        Subgroup of automorphisms of Abelian group with gap, generator orders (2, 3, 4, 5)
        generated by 6 automorphisms
    """
    Element = AbelianGroupAutomorphism

    def __init__(self, ambient, generators):
        """
        Constructor.

        TESTS::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.automorphism_group()
            sage: f = aut.an_element()
            sage: sub = aut.subgroup([f])
            sage: TestSuite(sub).run()
        """
        self._domain = ambient.domain()
        generators = tuple([g.gap() for g in generators])
        H = ambient.gap().Subgroup(generators)
        category = Groups().Finite().Enumerated()
        AbelianGroupAutomorphismGroup_gap.__init__(self,
                                                   self._domain,
                                                   gap_group=H,
                                                   category=category,
                                                   ambient=ambient)
        self._covering_matrix_ring = ambient._covering_matrix_ring

    def _repr_(self):
        r"""
        The string representation of ``self``.

        EXAMPLES::

            sage: from sage.groups.abelian_gps.abelian_group_gap import AbelianGroupGap
            sage: G = AbelianGroupGap([2,3,4,5])
            sage: aut = G.automorphism_group()
            sage: f = aut.an_element()
            sage: sub = aut.subgroup([f])
        """
        return "Subgroup of automorphisms of %s \n generated by %s automorphisms" % (
                        self.domain(), len(self.gens()))
