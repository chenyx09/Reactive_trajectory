from __future__ import print_function
import torch
import argparse
import torchvision.transforms as transforms
import matplotlib.pyplot as plt
import numpy as np
import torch.nn as nn
import torch.nn.functional as F
import pandas as pd
from scipy.io import loadmat
from torch.utils import data

device = 'cuda' if torch.cuda.is_available() else 'cpu'



class FCNet(nn.Module):
    def __init__(self, hidden_1=200, op_dim=17, input_dim=21):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, hidden_1)
        self.fc2 = nn.Linear(hidden_2, op_dim)
        self.fc3 = nn.Sigmoid()
        self.bn1 = nn.BatchNorm1d(hidden_1)

    def forward(self, x):
        output = F.relu(self.bn1(self.fc1(x)))
        output1 = self.fc2(output)
        output2 = self.fc3(output1)
        # output = F.log_softmax(output, dim=1)
        return output2, output

class FCNet_new(nn.Module):
    def __init__(self, hidden_1=100, hidden_2=50, op_dim=17, input_dim=21):
        super().__init__()
        self.fc1 = nn.Linear(input_dim, hidden_1)
        self.fc2 = nn.Linear(hidden_1, hidden_2)
        self.fc3 = nn.Linear(hidden_2, op_dim)
        self.fc4 = nn.Sigmoid()
        self.bn1 = nn.BatchNorm1d(hidden_1)
        self.bn2 = nn.BatchNorm1d(hidden_2)
    def forward(self, x):
        output = F.relu(self.bn1(self.fc1(x)))
        output = F.relu(self.bn2(self.fc2(output)))
        output1 = self.fc3(output)
        output2 = self.fc4(output1)
        # output = F.log_softmax(output, dim=1)
        return output2, output

def loss_function(X,Y):
    coeff = 100*(Y==1) + 5*(Y==0.0)+0.1*(Y==0.01)
    coeff1 = 100*(Y==1)
    coeff2 = 5*(Y==0.0)
    coeff3 = 0.1*(Y==0.01)
    ### TODO: Need to do normalize across the batch or something?
    # return torch.norm(coeff*(X-Y)**2)
    return torch.norm(coeff1*torch.relu(0.8-X)+coeff2*torch.relu(X-0.2)+coeff3*torch.relu(X-0.2))
    # return torch.norm(coeff*(Y*torch.log(X+0.01)+(1.0-Y)*torch.log(1.01-X)))

def train(args, model, device, train_loader, optimizer, epoch):
    model.train()
    for batch_idx, (input, target) in enumerate(train_loader):
        input, target = input.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(input)[0]
        loss = loss_function(output, target)
        loss.backward()
        optimizer.step()
        if batch_idx % args.log_interval == 0:
            print('Train Epoch: {} [{}/{} ({:.0f}%)]\tLoss: {:.6f}'.format(
                epoch, batch_idx * len(input), len(train_loader.dataset),
                100. * batch_idx / len(train_loader), loss.item()))


def test(args, model, device, test_loader, epoch):
    model.eval()
    test_loss = 0
    correct = 0
    with torch.no_grad():
        for input, target in test_loader:
            input, target = input.to(device), target.to(device)
            output = model(input)[0]
            test_loss += loss_function(output, target).item()  # sum up batch loss
            pred = output.argmax(dim=1, keepdim=True)  # get the index of the max log-probability

    test_loss /= len(test_loader.dataset)
    print('\nTest set: Average loss: {:.4f}'.format(test_loss))


def calc_offset(model,data,target):
    output = model(data)[0]
    pos_output = (target==1)*output + 10*(target!=1)
    offset,indices = pos_output.min(0)
    return offset
def main():
    parser = argparse.ArgumentParser(description='PyTorch MNIST Example')

    parser.add_argument('--log-interval', type=int, default=10, metavar='N',
                        help='how many batches to wait before logging training status')
    parser.add_argument('--data-path', type=str, default='data.mat',
                        metavar='D', help='.mat file from which to read data')
    parser.add_argument('--num-epochs',type=int, default=50,
                        help='number of epochs to train')
    args = parser.parse_args()

    x = loadmat(args.data_path)
    affordance_data = x['training_data']
    output = x['output']
    output1 = output+0.01*(output==0)+(output==-1)
    affordance_data = torch.Tensor(affordance_data)
    output = torch.Tensor(output1)

    output_shape = output.shape[1]

    model = FCNet_new(op_dim=output_shape).to(device)
    affordance_dataset = data.TensorDataset(affordance_data, output)

    train_data_size = int(0.85*len(affordance_dataset))
    test_data_size = int(0.1*len(affordance_dataset))
    val_data_size = len(affordance_dataset) - train_data_size - test_data_size

    #### Use 3 splits if needed by changing here
    train_data, val_data = torch.utils.data.random_split(affordance_dataset,
                                                            [train_data_size,
                                                            val_data_size +
                                                            test_data_size])


    train_loader = data.DataLoader(train_data, batch_size = 512)
    val_loader =   data.DataLoader(val_data, batch_size = 512)

    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
    # model.load_state_dict(torch.load('traj_pred.pth'))
    # model = torch.load('traj_pred.pth')
    test(args=args, model=model, device=device, test_loader=val_loader,
        epoch=0)
    for epoch in range(args.num_epochs):
        train(args=args, model=model, device=device, train_loader=train_loader,
              optimizer=optimizer, epoch=epoch)
        test(args=args, model=model, device=device, test_loader=val_loader,
        epoch=epoch)
    offset = calc_offset(model,affordance_data,output)
    print(offset)
    torch.save(model, 'traj_pred.pth')



    ## Get output before sigmoid
    # new_classifier = nn.Sequential(*list(model.classifier.children())[:-1])




if __name__ == '__main__':
    main()
