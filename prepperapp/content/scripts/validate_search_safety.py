#!/usr/bin/env python3
"""
Validate search safety for dangerous medical queries
Tests against the P0 SQLite content database
"""

import json
import sqlite3
import zstandard as zstd
from pathlib import Path
import sys
import re
from datetime import datetime
from typing import List, Dict, Tuple

# Test queries with safety concerns
TEST_QUERIES = [
    # High-Risk Ambiguous Phrases
    {
        "query": "cold water immersion",
        "category": "High-Risk Ambiguous",
        "safety_concern": "Could confuse hypothermia treatment with cold therapy",
        "danger_keywords": ["therapy", "treatment", "wellness"],
        "safe_keywords": ["hypotherm", "shock", "emergency", "drowning"]
    },
    {
        "query": "infant cpr dose",
        "category": "High-Risk Ambiguous",
        "safety_concern": "Critical to get correct infant-specific information",
        "danger_keywords": ["adult", "standard"],
        "safe_keywords": ["infant", "baby", "pediatric", "newborn"]
    },
    {
        "query": "tourniquet nerve damage",
        "category": "High-Risk Ambiguous",
        "safety_concern": "User might be looking for when NOT to use tourniquet",
        "danger_keywords": [],
        "safe_keywords": ["tourniquet", "bleeding", "hemorrhage"]
    },
    {
        "query": "do not apply heat",
        "category": "High-Risk Ambiguous",
        "safety_concern": "Negation might not be understood correctly",
        "danger_keywords": ["apply heat", "warm"],
        "safe_keywords": ["frostbite", "burn", "do not"]
    },
    
    # Action Queries
    {
        "query": "stop bleeding",
        "category": "Action Query",
        "safety_concern": None,
        "safe_keywords": ["pressure", "hemorrhage", "tourniquet", "bleeding"]
    },
    {
        "query": "snake bite treatment",
        "category": "Action Query", 
        "safety_concern": None,
        "safe_keywords": ["snake", "venom", "antivenom", "bite"]
    },
    
    # Symptom Queries
    {
        "query": "chest pain emergency",
        "category": "Symptom Query",
        "safety_concern": None,
        "safe_keywords": ["cardiac", "heart", "emergency", "chest"]
    },
    
    # Common Emergency Searches
    {
        "query": "hemorrhage control",
        "category": "Emergency",
        "safety_concern": None,
        "safe_keywords": ["bleeding", "pressure", "tourniquet"]
    },
    {
        "query": "cardiac arrest",
        "category": "Emergency",
        "safety_concern": None,
        "safe_keywords": ["cpr", "heart", "cardiac", "emergency"]
    }
]

class SearchValidator:
    def __init__(self, db_path: Path, jsonl_path: Path):
        self.db_path = db_path
        self.jsonl_path = jsonl_path
        self.decompressor = zstd.ZstdDecompressor()
        
        # Load article metadata from JSONL
        self.articles = {}
        self.load_article_metadata()
        
    def load_article_metadata(self):
        """Load article titles and IDs from JSONL"""
        print("Loading article metadata...")
        with open(self.jsonl_path, 'r') as f:
            for line in f:
                article = json.loads(line)
                self.articles[article['id']] = {
                    'title': article['title'],
                    'priority': article['priority'],
                    'keywords': article.get('keywords', [])
                }
        print(f"Loaded {len(self.articles)} articles")
    
    def search_content(self, query: str, limit: int = 5) -> List[Tuple[str, str, str, float]]:
        """
        Simple keyword search in SQLite content
        Returns: [(id, title, snippet, relevance_score)]
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get all article IDs and content
        cursor.execute("SELECT id, content FROM articles")
        
        results = []
        query_terms = query.lower().split()
        
        for article_id, compressed_content in cursor.fetchall():
            # Decompress content
            content = self.decompressor.decompress(compressed_content).decode('utf-8', errors='ignore')
            content_lower = content.lower()
            
            # Calculate relevance score (simple term frequency)
            score = 0
            matches = []
            
            for term in query_terms:
                count = content_lower.count(term)
                if count > 0:
                    score += count
                    # Find snippet around first match
                    pos = content_lower.find(term)
                    if pos >= 0:
                        start = max(0, pos - 100)
                        end = min(len(content), pos + 100)
                        snippet = content[start:end]
                        matches.append(snippet)
            
            if score > 0 and article_id in self.articles:
                title = self.articles[article_id]['title']
                snippet = matches[0] if matches else content[:200]
                results.append((article_id, title, snippet, score))
        
        conn.close()
        
        # Sort by relevance and return top results
        results.sort(key=lambda x: x[3], reverse=True)
        return results[:limit]
    
    def analyze_results(self, query_info: Dict, results: List[Tuple]) -> Dict:
        """Analyze search results for safety concerns"""
        analysis = {
            "query": query_info["query"],
            "category": query_info["category"],
            "safety_concern": query_info.get("safety_concern"),
            "results_found": len(results),
            "top_results": [],
            "safety_status": "SAFE",
            "analysis": ""
        }
        
        if not results:
            analysis["safety_status"] = "WARNING"
            analysis["analysis"] = "No results found - users might not find critical information"
            return analysis
        
        # Analyze top results
        for i, (article_id, title, snippet, score) in enumerate(results[:3]):
            analysis["top_results"].append({
                "rank": i + 1,
                "title": title,
                "score": score,
                "id": article_id
            })
        
        # Check for safety concerns in top result
        if query_info.get("safety_concern"):
            top_title = results[0][1].lower()
            top_snippet = results[0][2].lower()
            
            # Check for danger keywords
            danger_found = False
            if "danger_keywords" in query_info:
                for danger in query_info["danger_keywords"]:
                    if danger in top_title or danger in top_snippet:
                        danger_found = True
                        analysis["safety_status"] = "CONCERN"
                        analysis["analysis"] = f"Top result contains potentially dangerous term: '{danger}'"
                        break
            
            # Check for safe keywords
            if not danger_found and "safe_keywords" in query_info:
                safe_found = False
                for safe in query_info["safe_keywords"]:
                    if safe in top_title or safe in top_snippet:
                        safe_found = True
                        break
                
                if safe_found:
                    analysis["analysis"] = "Top results contain appropriate safety terms"
                else:
                    analysis["safety_status"] = "WARNING"
                    analysis["analysis"] = "Top results may not address the safety concern adequately"
        else:
            # General relevance check
            if "safe_keywords" in query_info:
                keywords_found = sum(1 for kw in query_info["safe_keywords"] 
                                   if kw in results[0][1].lower() or kw in results[0][2].lower())
                if keywords_found > 0:
                    analysis["analysis"] = f"Results contain {keywords_found} expected keywords"
                else:
                    analysis["safety_status"] = "WARNING"
                    analysis["analysis"] = "Results may not be sufficiently relevant"
            else:
                analysis["analysis"] = "Results appear relevant based on keyword matching"
        
        return analysis

def main():
    # Paths
    script_dir = Path(__file__).parent
    data_dir = script_dir.parent.parent / "data"
    db_path = data_dir / "processed-p0" / "content-p0.sqlite"
    jsonl_path = data_dir / "processed-p0" / "articles-p0.jsonl"
    
    # Check files exist
    if not db_path.exists():
        print(f"Error: P0 SQLite database not found at: {db_path}")
        print("Please run P0_ONLY_EXTRACT.sh first")
        sys.exit(1)
    
    if not jsonl_path.exists():
        print(f"Error: P0 JSONL file not found at: {jsonl_path}")
        sys.exit(1)
    
    print("🔍 PrepperApp Content Safety Validation")
    print(f"Database: {db_path}")
    print(f"Testing {len(TEST_QUERIES)} queries\n")
    
    # Create validator
    validator = SearchValidator(db_path, jsonl_path)
    
    # Run tests
    all_results = []
    concerning_results = 0
    
    for query_info in TEST_QUERIES:
        print(f"\n📋 Testing: '{query_info['query']}'")
        print(f"   Category: {query_info['category']}")
        if query_info.get('safety_concern'):
            print(f"   ⚠️  Concern: {query_info['safety_concern']}")
        
        # Search
        results = validator.search_content(query_info['query'])
        
        # Analyze
        analysis = validator.analyze_results(query_info, results)
        all_results.append(analysis)
        
        # Display results
        if results:
            print("\n   Top results:")
            for i, (_, title, _, score) in enumerate(results[:3]):
                print(f"   {i+1}. [{score:.1f}] {title}")
        
        # Display analysis
        status_icon = "✅" if analysis["safety_status"] == "SAFE" else "⚠️"
        print(f"\n   {status_icon} Status: {analysis['safety_status']}")
        print(f"   Analysis: {analysis['analysis']}")
        
        if analysis["safety_status"] != "SAFE":
            concerning_results += 1
    
    # Summary
    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Total queries tested: {len(TEST_QUERIES)}")
    print(f"Queries with concerns: {concerning_results}")
    
    if concerning_results == 0:
        print("\n✅ All queries returned safe and relevant results!")
        print("\nRecommendation: Content appears safe for Basic indexing without phrase search.")
    else:
        print(f"\n⚠️  {concerning_results} queries had potential safety concerns")
        print("\nRecommendation: Review concerning queries and consider mitigations.")
    
    # Save results
    output_path = script_dir / "search_safety_validation_results.json"
    with open(output_path, 'w') as f:
        json.dump({
            "test_date": datetime.now().isoformat(),
            "database": str(db_path),
            "total_queries": len(TEST_QUERIES),
            "concerning_results": concerning_results,
            "results": all_results
        }, f, indent=2)
    
    print(f"\n📄 Detailed results saved to: {output_path}")

if __name__ == "__main__":
    main()