aws cloudformation create-stack \
 --stack-name  eks-network-stack \
 --template-body file://1-network.yaml \
 --capabilities CAPABILITY_NAMED_IAM

aws cloudformation create-stack \
 --stack-name  eks-stack \
 --template-body file://2-eks.yaml \
 --capabilities CAPABILITY_NAMED_IAM

aws cloudformation create-stack \
 --stack-name  iam-stack \
 --template-body file://3-iam.yaml \
 --capabilities CAPABILITY_NAMED_IAM

aws cloudformation update-stack \
 --stack-name  iam-stack \
 --template-body file://3-iam.yaml \
 --capabilities CAPABILITY_NAMED_IAM

# aws eks update-kubeconfig --name eks-stack-eks-cluster
# kubectl -n kube-system get serviceaccount/ebs-csi-controller-sa -o yaml