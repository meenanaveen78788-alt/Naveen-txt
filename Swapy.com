import requests
import json

def get_all_batches():
    """Fetch all available batches"""
    url = "https://hackerfreesw.vercel.app/batches"
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except:
        return []

def get_batch_details(batch_id):
    """Fetch detailed information for a specific batch"""
    url = f"https://hackerfreesw.vercel.app/extract/batch_id={batch_id}"
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except:
        return None

def select_batch(batches):
    """Display batches and let user select one"""
    print("\n" + "="*50)
    print("AVAILABLE BATCHES")
    print("="*50)
    
    for i, batch in enumerate(batches, 1):
        print(f"{i}. {batch.get('batchName', 'N/A')}")
        print(f"   ID: {batch.get('batchId', 'N/A')}")
        print(f"   Price: â‚¹{batch.get('discountPrice', 'N/A')}")
        print()
    
    while True:
        try:
            choice = int(input(f"Select batch (1-{len(batches)}): "))
            if 1 <= choice <= len(batches):
                return batches[choice-1]
        except:
            pass
        print(f"Enter 1-{len(batches)}")

def get_video_link(video_links):
    """Get video link (720p > 480p > 360p > 240p)"""
    for quality in ['720p', '480p', '360p', '240p']:
        for link in video_links:
            if link.get('quality') == quality:
                return link.get('url')
    return ""

def extract_links(batch_details):
    """Extract all links"""
    all_links = []
    
    # Topics ke videos aur PDFs
    for topic in batch_details.get("topics", []):
        topic_name = topic.get("topicName", "")
        
        for lecture in topic.get("lectures", []):
            # Video link
            video_url = get_video_link(lecture.get("videoLinks", []))
            if video_url:
                all_links.append({
                    "type": "video",
                    "topic": topic_name,
                    "title": lecture.get("videoTitle", ""),
                    "url": video_url
                })
            
            # PDF links from lecture
            for pdf in lecture.get("pdfLinks", []):
                all_links.append({
                    "type": "pdf",
                    "topic": topic_name,
                    "title": pdf.get("name", ""),
                    "url": pdf.get("url", "")
                })
    
    # Study material PDFs
    for material in batch_details.get("studyMaterial", []):
        for pdf in material.get("pdfs", []):
            all_links.append({
                "type": "study_pdf",
                "topic": material.get("topic", "Study Material"),
                "title": pdf.get("title", ""),
                "url": pdf.get("link", "")
            })
    
    return all_links

def save_links(batch_name, batch_image, links):
    """Save links in exact format"""
    filename = batch_name.replace(" ", "_").replace("/", "-") + ".txt"
    
    with open(filename, 'w', encoding='utf-8') as f:
        # Batch image
        f.write(f"Batch Image: {batch_image}\n\n")
        
        # All links
        for link in links:
            if link["url"]:  # Only write if URL exists
                f.write(f"({link['topic']}) {link['title']} : {link['url']}\n")
    
    print(f"\nâœ“ Saved to: {filename}")
    print(f"âœ“ Total links: {len([l for l in links if l['url']])}")

def main():
    print("Batch Link Extractor")
    
    # Get batches
    batches = get_all_batches()
    if not batches:
        print("No batches found!")
        return
    
    # Select batch
    selected = select_batch(batches)
    batch_id = selected.get("batchId")
    batch_name = selected.get("batchName")
    batch_image = selected.get("batchThumb", "")
    
    print(f"\nFetching: {batch_name}")
    
    # Get details
    details = get_batch_details(batch_id)
    if not details:
        print("Failed to get details!")
        return
    
    # Extract links
    links = extract_links(details)
    
    # Save to file
    save_links(batch_name, batch_image, links)

if __name__ == "__main__":
    main()
