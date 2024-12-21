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
// import { generateVoters } from './generate-merkle-tree.js';

const contractAddress = '0xa51c1fc2f0d1a1b8494ed1fe312d7c3a78ed91c0'; // your contract address

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

  console.log(`TESTING TREE: ${treeData.values.length} voters`);

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
    console.log('Testing verification for whitelisted voters. EXPECTING true');
    console.log('isValid', isValid);

    console.log('\nVerification result:', isValid ? '✅ Success' : '❌ Failed');
    successCount += isValid ? 1 : 0;
  }

  return successCount;
};

const generateRandomProof = () => {
  return Array(6)
    .fill(0)
    .map(
      () =>
        `0x${Array(64)
          .fill(0)
          .map(() => Math.floor(Math.random() * 16).toString(16))
          .join('')}` as Hex
    );
};

// const _testNonWhitelistVoters = async () => {
//   const wrongVoters = generateVoters(100);

//   let failCount = 0;

//   for (let i = 0; i < wrongVoters.length; i++) {
//     const randomProof = generateRandomProof();

//     const [firstVoterAddress, firstVoterPoints] = wrongVoters[i];

//     // Verify on contract
//     const isValid = await client.readContract({
//       address: contractAddress,
//       abi: ABI,
//       functionName: 'verifyPoints',
//       args: [
//         firstVoterAddress as Address,
//         BigInt(firstVoterPoints),
//         randomProof as Hex[],
//       ],
//     });
//     console.log(
//       'Testing verification for non-whitelisted voters. EXPECTING false'
//     );
//     console.log('isValid', isValid);

//     console.log('\nVerification result:', isValid ? '❌ Failed' : '✅ Success');

//     failCount += !isValid ? 1 : 0;
//   }
//   return failCount;
// };

async function main() {
  const successCount = await _testAllVoters();
  // const failCount = await _testNonWhitelistVoters();
  console.log('\n\nSuccess count:', successCount);
  // console.log('\n\nFail count:', failCount);
}

main().catch(console.error);
