import { StandardMerkleTree } from '@openzeppelin/merkle-tree';
import {
  Address,
  createPublicClient,
  encodeAbiParameters,
  Hex,
  http,
  keccak256,
} from 'viem';
import { foundry } from 'viem/chains';
import { ABI } from './merklePointsAbi.js';
import fs from 'fs/promises';
import path from 'path';

const contractAddress = '0x5fbdb2315678afecb367f032d93f642f64180aa3'; // your contract address

type MerkleTreeData = {
  format: 'standard-v1';
  leafEncoding: string[];
  tree: string[];
  values: { value: string[]; treeIndex: number }[];
};

const getTreeData = async () => {
  try {
    const data = await fs.readFile(
      path.join(process.cwd(), 'merkle-data', 'merkle-info.json')
    );

    const parsedData = JSON.parse(data.toString());

    const treeData = parsedData.tree as MerkleTreeData;
    const root = parsedData.merkleRoot as Hex;

    return { treeData, root };
  } catch (error) {
    console.error(error);
  }
};

const client = createPublicClient({
  chain: foundry,
  transport: http('http://127.0.0.1:8545'),
});

const _testAllVoters = async () => {
  let successCount = 0;

  const { treeData, root } = (await getTreeData()) || {};

  if (!treeData || !root) {
    console.error('No tree data found');
    return;
  }

  for (let i = 0; i < treeData.values.length; i++) {
    const voterIndex = i;
    // Reconstruct the tree from saved data
    const tree = StandardMerkleTree.load(treeData as MerkleTreeData);

    // Get first voter's data and proof
    const [firstVoterAddress, firstVoterPoints] =
      treeData.values[voterIndex].value;
    const proof = tree.getProof(voterIndex);

    // Generate leaf hash the way contract does it
    const encodedData = encodeAbiParameters(
      [{ type: 'address' }, { type: 'uint256' }],
      [firstVoterAddress as Address, BigInt(firstVoterPoints)]
    );
    const contractLeaf = keccak256(encodedData);

    const offChainVerification = tree.verify(
      [firstVoterAddress, firstVoterPoints],
      proof
    );

    console.log('Testing verification for:');
    console.log('Address:', firstVoterAddress);
    console.log('Points:', firstVoterPoints);
    console.log('Proof:', proof);
    console.log('\nLeaf hash we calculate:', contractLeaf);

    console.log(
      '\nOff-chain verification:',
      offChainVerification ? '✅ Success' : '❌ Failed'
    );

    const contractRoot = await client.readContract({
      address: contractAddress,
      abi: ABI,
      functionName: 'merkleRoot',
    });

    console.log('\nContract root:', contractRoot);
    console.log('Tree root:     ', tree.root);
    console.log('Roots match:', contractRoot === tree.root);

    // Verify on contract
    const isValid = await client.readContract({
      address: contractAddress,
      abi: ABI,
      functionName: 'verifyPoints',
      args: [
        firstVoterAddress as Address,
        BigInt(firstVoterPoints),
        proof as Hex[],
      ],
    });

    console.log('\nVerification result:', isValid ? '✅ Success' : '❌ Failed');

    successCount += isValid ? 1 : 0;
  }

  console.log('\n\nSuccess count:', successCount);
};

async function main() {
  _testAllVoters();
}

// async function main() {
//   const tree = StandardMerkleTree.load(treeData as MerkleTreeData);

//   // Use entries() instead of accessing values directly
//   const [[, [firstVoterAddress, firstVoterPoints]]] = tree.entries();
//   const proof = tree.getProof(0);

//   // Log raw data
//   console.log('Raw data:');
//   console.log('Address:', firstVoterAddress);
//   console.log('Points:', firstVoterPoints);

//   // Try our leaf generation
//   const encodedData = encodeAbiParameters(
//     [{ type: 'address' }, { type: 'uint256' }],
//     [firstVoterAddress as Address, BigInt(firstVoterPoints)]
//   );
//   const contractLeaf = keccak256(encodedData);
//   console.log('\nOur leaf hash:', contractLeaf);

//   // Let's also see if the proof works with this leaf
//   const ozVerify = tree.verify([firstVoterAddress, firstVoterPoints], proof);
//   console.log('\nOZ verification:', ozVerify);
// }

main().catch(console.error);
