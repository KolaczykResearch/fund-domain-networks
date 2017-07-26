#initialize
n = eval(raw_input("Please specify n: "))
N=binomial(n,2)

#list of unordered pairs of elements in {1,...,n}
def pairs(n): return flatten([[[i+1,j+1] for j in range(i+1,n)] for i in range(n-1)],max_level=1)

#sigma acts on an unordered pair
def act(sigma, p): return sorted([sigma(p[0]),sigma(p[1])])

#sigma acts as matrix in basis B on a vector v
def act_vect(sig,v,B=identity_matrix(N)): return (B.inverse()*sig.matrix()*B)*v

#permutation in Sigma_N which induced from perm in Sigma_n
def embed(sigma,n): return perm_from_sort([act(sigma,p) for p in pairs(n)])

#find permutation which orders a list L	
def perm_from_sort(L): return Permutation([pair[0] for pair in sorted(enumerate(L, 1), key=lambda x: x[1])]).to_cycles()

#image of generators of Sigma_n under embedding into Sigma_N
def embed_gens(n): return [embed(gen,n) for gen in SymmetricGroup(n).gens()]

G = PermutationGroup(embed_gens(n))

#fundamental domain given arbitrary distinct vector l and basis B
def fund_domain(l=[i for i in range(N)],B=identity_matrix(N),br=QQ):

	#augmented matrix for half-plane ineqs
	A = [ [l[j] - act_vect(G[i],vector(l),B)[j] for j in range(N)] for i in range(G.order())]
	b_1 = [0 for i in range(G.order())]
	bA = matrix(br,b_1).transpose().augment(matrix(br,A))

	#augmented matrix for positivity ineqs
	pos = B.inverse().transpose()
	b_2 = [0 for i in range(N)]
	bPos = matrix(br,b_2).transpose().augment(pos)

	#augmented matrix for fund. domain
	aug_l = bA.stack(bPos)
	
	#find convex polyhedral region, i.e. intersection of all ineqs
	poly = Polyhedron(ieqs=aug_l,base_ring=br)
	
	return([aug_l,poly])

	
#translation decomposition of fundamental domain F_l at x	
def fund_decomp(x,l=[i for i in range(N)],br=QQ):

	VR = []
	
	for k in range(G.order()):
		
		#fund. domain centered at l
		F_l = fund_domain(l)[0]
		
		#fund. domain centered at sigma.x
		sig_x = [x[G[k].inverse()(i+1)-1] for i in range(len(x))]
		F_sig_x = fund_domain(sig_x)[0]
		
		#intersection of F_l and F_sig_x
		int = F_l.stack(F_sig_x)
		
		#find convex polyhedral region corresponding to intersection
		poly = Polyhedron(ieqs=int,base_ring=br)
		
		#check uniqueness
		isUnique = True
		for i in range(len(VR)):
			if poly == VR[i][0]: 
				isUnique = False
				VR[i][1].append(G[k])
		if isUnique == True:
			VR.append([poly,[G[k]]])
	
				
	return(VR)
	
#compactify a convex cone by adding a plane normal to x
def compactify(region,comp_dir=[1 for i in range(N)],chi=10,br=None):
	if br==None: br=region.base_ring()
	P_chi = [-comp_dir_i for comp_dir_i in comp_dir]
	P_chi.insert(0,chi)
	ieqs_list = [list(ieqs_i) for ieqs_i in region.inequalities()]
	ieqs_list.append(P_chi)
	return Polyhedron(ieqs=ieqs_list,base_ring=br)

#compactify fund. domain over QQ in direction comp_dir w/ cutoff chi
#and compute volume using optional Sage package 'lrslib'
def lrs_vol(region,comp_dir=[1 for i in range(N)],chi=10): return compactify(region,comp_dir,chi,QQ).volume(engine='lrs')

#given Vrepresentation of fund. domain computed in QQ, approximate  
#normalized rays over RR and remove duplicates
def vRep_approx(F_x,prec=53): 
	ray_approx=list(set([tuple(vector(RealField(prec),v)/norm(vector(RealField(prec),v))) for v in F_x.ray_generator()]))
	vert_approx=[vector(RealField(prec),v) for v in F_x.vertices_list()]
	return ray_approx+vert_approx


#compare two fundamental domains
def compare_domains(F_1,F_2):
	
	#domains
	print('Domains: \n F_1: %r \n F_2: %r' % (F_1, F_2))
	
	#check to see if they're the same
	if F_1 == F_2: print('Same Regions in R^%r' % N)
	else: print('Different Regions in R^%r' % N)
	
	#volumes
	print('Volumes: \n V_1=%r \n V_2=%r' % (lrs_vol(F_1),lrs_vol(F_2)))
	
	#number of planes in H-rep
	print('#H-rep: \n #F_1=%r \n #F_2=%r' % (F_1.n_Hrepresentation(),F_2.n_Hrepresentation()))

#orbit of point x under grounp action			
def orb(x): return list(set([tuple(act_vect(g,vector(x))) for g in G]))

#return orbit rep of x lying in F
def fund_domain_rep(x, F):
	for gx in orb(x):
		if F.contains(gx): return gx.list()

#size of stabilizer of point x
def stab_size(x): return factorial(n)/len(orb(x))

#returns interior point of polyhedron = average of vertices and rays 
#whose convex hull is polyhedron
def int_point(poly): 
	vert_rays = poly.vertices_list()+poly.rays_list()
	p = (1/len(vert_rays))*sum(vector(vr) for vr in vert_rays)
	#check
	if poly.relative_interior_contains(p): return p
	else: return "Failed."

#check if two faces of a polyhedron are glued together by group action
def faces_glued(f1,f2):
	p1 = int_point(f1.as_polyhedron())
	poly2 = f2.as_polyhedron()
	for o1 in orb(p1):
		if poly2.relative_interior_contains(o1): return True
	return False
	
#return list of lists of k-dim faces of polyhedron F after accounting for gluing by group
#action
def glued_face_lattice(F):
	glued_face_lat = []
	for k in range(N+1):
		new_k_faces = []
		#faces which are glued are considered duplicate
		for face in F.faces(k):
			#check if face is already in new_k_faces
			contains_face = False
			for new_face in new_k_faces: 
				if(faces_glued(face,new_face)): contains_face = True
			if not contains_face: new_k_faces.append(face)
		glued_face_lat.append(new_k_faces)
	return glued_face_lat

#returns orbifold Euler characteristic given fundamental domain F for orbifold X/G.
#takes into account glued faces as to not include extra terms in alternating sum.
def orb_euler_char(F):
	#use face lattice which removes duplicate/glued faces
	glued_face_lat = glued_face_lattice(F)
	#initialize alternating sum
	alt_sum = 0
	#loop over faces of each dim. k
	for k in range(N+1):
		for f in glued_face_lat[k]:
			#convert face to polyhedron object
			f_poly = f.as_polyhedron()
			#choose arbitrary interior point of face
			p = int_point(f_poly)
			#add summand
			alt_sum += (-1)^k*(1/stab_size(p))
	return alt_sum


#extract info from decomp vector
def dim_vector(decomp): return sorted([R[0].dim() for R in decomp])
def polys(decomp): return [R[0] for R in decomp]
def perms(decomp): return [R[1] for R in decomp]
def facet_graphs(decomp): return [Graph(R[0].facet_adjacency_matrix()) for R in decomp]
def top_dim_cells(decomp): 
	L=[]; 
	for i in range(len(decomp)):
		if decomp[i][0].dim() == N: L.append(decomp[i]) 
	return L
		
	









		
